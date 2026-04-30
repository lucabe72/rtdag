DIR=$1

NUM_0_TASKS=5
NUM_4_TASKS=5

FIRST_Y=$(ls ${DIR}/*.yaml | head -n1)
FREQ_4=$(grep freq ${FIRST_Y} | cut -d',' -f5)
FREQ_0=$(grep freq ${FIRST_Y} | cut -d',' -f2)
FREQ_0=${FREQ_0}000
FREQ_4=${FREQ_4}000
OMP_FILES=$(ls ${DIR}/*.yaml | grep omp)
THR_FILES=$(ls ${DIR}/*.yaml | grep -v omp)

get_cluster() {
  grep affinity $1
}

get_0() {
  for F in $1
   do
    A=$(grep affinity $F)
    echo $A | grep 0 > /dev/null || echo $A | grep 1 > /dev/null || echo $A | grep 2 > /dev/null || echo $A | grep 3 > /dev/null && echo $F
   done
}

get_4() {
  for F in $1
   do
    grep affinity $F | grep 4 > /dev/null || grep affinity $F | grep 5 > /dev/null ||grep affinity $F | grep 6 > /dev/null || grep affinity $F | grep 7 > /dev/null && echo $F
   done
}

get_affs_internal() {
  #grep affinity $1 | cut -d'[' -f2 | cut -d']' -f1 |  { while read -d, i; do echo $i; done; echo $i; }
  for F in $1
   do
    AA=$(grep affinity $F | cut -d'[' -f2 | cut -d']' -f1)
    OLDIF=${IFS}
    IFS=','
    for i in ${AA}
     do
      echo $i
     done
    IFS=${OLDIF}
   done
}

get_affs() {
  TMP=$(get_affs_internal "$1" | sort -n | uniq)
  AFFS=""
  for A in ${TMP}
   do
    AFFS="${AFFS},$A"
   done
  AFFS=$(echo ${AFFS} | cut -d',' -f1 --complement)
  echo ${AFFS}
}

subtract() {
  RES=""
  OI=${IFS}
  IFS=','
  for I in $1
   do
    echo $2 | grep $I > /dev/null || RES="${RES},$I"
   done
  IFS=${OI}
  echo ${RES} | cut -d',' -f1 --complement
}

echo OMP Tests:
for F in ${OMP_FILES}
 do
  A=$(get_cluster $F)
  echo $F: $A
 done

echo Threaded Tests:
for F in ${THR_FILES}
 do
  A=$(get_cluster $F)
  echo $F: $A
 done

echo Frequency for Little: ${FREQ_0}
echo Frequency for big: ${FREQ_4}
sudo FREQ_0=${FREQ_0} su -c "echo ${FREQ_0} > /sys/devices/system/cpu/cpufreq/policy0/scaling_setspeed"
sudo FREQ_4=${FREQ_4} su -c "echo ${FREQ_4} > /sys/devices/system/cpu/cpufreq/policy4/scaling_setspeed"

OMP_0_FILES=$(get_0 "${OMP_FILES}")
OMP_4_FILES=$(get_4 "${OMP_FILES}")

echo OMP 0: ${OMP_0_FILES}
echo OMP 4: ${OMP_4_FILES}
echo THR: ${THR_FILES}

if [ "x${OMP_0_FILES}" != "x" ]
 then
  OMP_CPUS=$(get_affs "${OMP_0_FILES}")
  THR_CPUS=$(get_affs "${THR_FILES}")
  OMP_CPUS="0,1,2,3"
  if [ "x${THR_FILES}" != "x" ]
   then
    OMP_CPUS=$(subtract "0,1,2,3" ${THR_CPUS})
   fi
  NUM_0_TASKS=$(echo ${OMP_CPUS} | tr -cd , | wc -c)
  NUM_0_TASKS=$((NUM_0_TASKS+2))
  echo OMP CPUs 0: ${OMP_CPUS} / ${NUM_0_TASKS}
  export OMP_NUM_THREADS=${NUM_0_TASKS}
  TICKS_PER_US=0.512472 taskset -c ${OMP_CPUS} rtdag/Build/rtdag ${OMP_0_FILES} > omp_0.log 2> omp_0.err &
 fi

if [ "x${OMP_4_FILES}" != "x" ]
 then
  OMP_CPUS=$(get_affs "${OMP_4_FILES}")
  THR_CPUS=$(get_affs "${THR_FILES}")
  OMP_CPUS="4,5,6,7"
  if [ "x${THR_FILES}" != "x" ]
   then
    OMP_CPUS=$(subtract "4,5,6,7" ${THR_CPUS})
   fi
  NUM_4_TASKS=$(echo ${OMP_CPUS} | tr -cd , | wc -c)
  NUM_4_TASKS=$((NUM_4_TASKS+2))
  echo OMP CPUs 4: ${OMP_CPUS} / ${NUM_4_TASKS}
  export OMP_NUM_THREADS=${NUM_4_TASKS}
  TICKS_PER_US=0.512472 taskset -c ${OMP_CPUS} rtdag/Build/rtdag ${OMP_4_FILES} > omp_4.log 2> omp_4.err &
 fi

if [ "x${THR_FILES}" != "x" ]
 then
  TICKS_PER_US=0.512472 rtdag-noomp/Build/rtdag ${THR_FILES} > thr.log 2> thr.err &
 fi

wait
wait
wait
