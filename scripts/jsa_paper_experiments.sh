DIRS=$(ls $1)

for D in ${DIRS}
 do
  echo Running $D...
  sh run_one_experiment.sh $1/$D
  mkdir -p Logs/$D
  mv *.err *.log Logs/$D
  echo Done!
 done

