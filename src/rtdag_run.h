#ifndef RTDAG_RUN_H
#define RTDAG_RUN_H

#include <sys/syscall.h> /* For SYS_gettid definitions */
#include <iostream>

#include "input/input.h"
#include "newstuff/taskset.h"

#include <cstring>
#include <sys/stat.h>
#include <omp.h>

// the dag definition is here
// #include "task_set.h"

// using namespace std;

////////////////////////////
// globals used by the tasks
////////////////////////////
// check the end-to-end DAG deadline
// the start task writes and the final task reads from it to
// unsigned long dag_start_time;
std::vector<int> pid_list;

// void exit_all([[maybe_unused]] int sigid) {
// #if TASK_IMPL == TASK_IMPL_THREAD
//     printf("Killing all threads\n");
//     // TODO: how to kill the threads without access to the thread list ?
// #else
//     printf("Killing all tasks\n");
//     unsigned i, ret;
//     for (i = 0; i < pid_list.size(); ++i) {
//         ret = kill(pid_list[i], SIGKILL);
//         assert(ret == 0);
//     }
// #endif
//     printf("Exting\n");
//     exit(0);
// }

int get_ticks_per_us(bool required);

pid_t gettid(void)
{
  return syscall(SYS_gettid);
}

void set_omp_thread_scheduling(void)
{
  //std::cout << "Thread " << omp_get_thread_num() << " / " <<  omp_get_num_threads() << std::endl;
  struct sched_param sp;
  int tid, res;

  tid = gettid();
  sp.sched_priority = 90;
  res = sched_setscheduler(tid, SCHED_FIFO, &sp);
  if (res < 0) {
    std::cerr << "ERROR in SetScheduler: " << res << std::endl;

    exit(-1);
  }
}

int run_dag(const std::vector<std::string> &in_fname) {
    // uncomment this to get a random seed
    // unsigned seed = time(0);
    // or set manually a constant seed to repeat the same sequence
    unsigned seed = 123456;
    std::cout << "SEED: " << seed << std::endl;

    // Check whether the environment contains the TICKS_PER_US variable
    int ret = get_ticks_per_us(true);
    if (ret) {
        return ret;
    }

    std::vector<DagTaskset *> tsets;
    for (const auto &fname : in_fname) {
      // read the dag configuration from the selected type of input
      std::unique_ptr<input_base> inputs =
        std::make_unique<input_type>(fname.c_str());
      dump(*inputs);
      DagTaskset *ts = new DagTaskset(*inputs);
      tsets.push_back(ts);
      std::cout << "\nPrinting the input DAG: \n";
      ts->print(std::cout);
      // create the directory where execution time are saved
      struct stat st; // This is C++, you cannot use {0} to initialize to zero an
                      // entire struct.
      memset(&st, 0, sizeof(struct stat));
      if (stat(ts->dag.name.c_str(), &st) == -1) {

        // permisions required in order to allow using rsync since rt-dag is run
        // as root in the target computer
        int rv = mkdir(ts->dag.name.c_str(), 0777);
        if (rv != 0) {
            perror("ERROR creating directory");
            exit(1);
        }
      }

      // pass pid_list such that tasks can be killed with CTRL+C
#pragma omp parallel
      {
        set_omp_thread_scheduling();
#pragma omp single
        {
          ts->launch(pid_list, seed);
        }
      }
    }
    LOG(INFO, "[main] waiting for all tasks...\n");
    for (const auto &ts : tsets) {
      ts->wait();
    }
    // "" is used only to avoid variadic macro warning
    LOG(INFO, "[main] all tasks were finished%s...\n", " ");

    return 0;
}
#endif // RTDAG_RUN_H
