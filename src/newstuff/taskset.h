#ifndef RTDAG_TASKSET_H
#define RTDAG_TASKSET_H

#include "input/input.h"
#include "rtask.h"

#include <barrier>

struct DagTaskset {
    Dag dag;
    std::vector<Task*> tasks;

public:
    DagTaskset(const input_base &input);

    void print(std::ostream &os);

    void launch(std::vector<int> &pids, unsigned seed);
    void wait();
};

#endif // RTDAG_TASKSET_H
