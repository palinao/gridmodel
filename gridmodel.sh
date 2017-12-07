#!/bin/bash
echo Linear kernel
printf -v res %20s
printf '%s\n' "${res// /-}"
max=0
tune=2

for i in {-10..6}
do
  tradeoff=$(echo "scale=10; $tune^$i" | bc -l)
  output=$(.././svm-train -t 0 -c $tradeoff -v 10 -q svm_dataset/spam_train_std.txt)
  tmp=${output#*= }
  accuracy=${tmp%\%*}
  accuracies[$i+20]=$accuracy
  if (($(echo "$accuracy>$max" | bc -l)))
  then
    max=$accuracy
    optimal=$tradeoff
    index=$i+20
  fi
  printf "C: %1.10f Accuracy: %2.1f%%\n" $tradeoff $accuracy
done

if (($(echo "${accuracies[$index-1]}>${accuracies[$index+1]}" | bc -l)))
then
  lower=$(echo "$optimal/$tune" | bc -l)
  upper=$optimal
else
  lower=$optimal
  upper=$(echo "$optimal*$tune" | bc -l)
fi

function finesearch {
  increment=$(echo "($2-$1)/$3" | bc -l)
  max=0
  for ((i=0;i<=10;i++))
  do
    tradeoff=$(echo "scale=10; $1+$increment*$i" | bc -l)
    output=$(.././svm-train -t 0 -c $tradeoff -v 10 -q svm_dataset/spam_train_std.txt)
    tmp=${output#*= }
    accuracy=${tmp%\%*}
    accuracies[$i]=$accuracy
    if (($(echo "$accuracy>$max" | bc -l)))
    then
      max=$accuracy
      optimal=$tradeoff
      index=$i
    fi
  done
  if (($(echo "$index==0" | bc -l)))
  then
    lower=$optimal
    upper=$(echo "$optimal+$increment" | bc -l)
  elif (($(echo "${accuracies[$index-1]}>${accuracies[$index+1]}" | bc -l)))
  then
    lower=$(echo "$optimal-$increment" | bc -l)
    upper=$optimal
  else
    lower=$optimal
    upper=$(echo "$optimal+$increment" | bc -l)
  fi
  echo $lower._$upper
}

echo "Performing finesearch between" $lower "and" $upper
range=$(finesearch $lower $upper 10)
lower=${range%._*}
upper=${range#*._}
echo performing finesearch between $lower and $upper
range=$(finesearch $lower $upper 10)
lower=${range%._*}
upper=${range#*._}
echo "Performing finesearch between" $lower "and" $upper
range=$(finesearch $lower $upper 10)
lower=${range%._*}
upper=${range#*._}
param1=$(echo "($lower+$upper)/2" | bc -l)
output=$(.././svm-train -t 0 -c $param1 -v 10 -q svm_dataset/spam_train_std.txt)
tmp=${output#*= }
accuracy=${tmp%\%*}
echo "Tuned C value for linear kernel:" $param1 "Related accuracy: " $accuracy "%"

printf -v res %20s
printf '%s\n' "${res// /-}"
echo RBF kernel

for ((i=-10;i<=6;i++))
  do
  gammarange[$i+10]=$(echo "2^$i" | bc -l)
done

for ((i=-10;i<=6;i++))
  do
  tradeoffrange[$i+10]=$(echo "2^$i" | bc -l)
done

ii=0
max=0
for i in "${gammarange[@]}"
  do
  jj=0
  ii=$(($ii+1))
  for j in "${tradeoffrange[@]}"
    do
    jj=$(($jj+1))
    output=$(.././svm-train -t 2 -g $i -c $j -v 10 -q svm_dataset/spam_train_std.txt)
    tmp=${output#*= }
    accuracy=${tmp%\%*}
    printf "C: %1.10f G: %1.10f Accuracy: %2.1f%%\n" $j $i $accuracy
    if (($(echo "$accuracy>$max" | bc -l)))
    then
      max=$accuracy
      optimalgamma=$i
      optimaltradeoff=$j
      if (($ii<15))
      then
        gammau=${gammarange[$ii+1]}
      else
        gammau=${gammarange[$ii]}
      fi
      if (($jj<15))
      then
        tradeoffu=${tradeoffrange[$jj+1]}
      else
        tradeoffu=${tradeoffrange[$jj]}
      fi
      if (($ii>0))
      then
        gammad=${gammarange[$ii-1]}
      else
        gammad=${gammarange[$ii]}
      fi
      if (($jj>0))
      then
        tradeoffd=${tradeoffrange[$jj-1]}
      else
        tradeoffd=${tradeoffrange[$jj]}
      fi
    fi
  done
done

max=0
output=$(.././svm-train -t 2 -g $gammad -c $tradeoffd -v 10 -q svm_dataset/spam_train_std.txt)
tmp=${output#*= }
accuracy=${tmp%\%*}
if (($(echo "$accuracy>$max" | bc -l)))
then
  flag=1
  max=$accuracy
fi
output=$(.././svm-train -t 2 -g $gammau -c $tradeoffd -v 10 -q svm_dataset/spam_train_std.txt)
tmp=${output#*= }
accuracy=${tmp%\%*}
if (($(echo "$accuracy>$max" | bc -l)))
then
  flag=2
  max=$accuracy
fi
output=$(.././svm-train -t 2 -g $gammad -c $tradeoffu -v 10 -q svm_dataset/spam_train_std.txt)
tmp=${output#*= }
accuracy=${tmp%\%*}
if (($(echo "$accuracy>$max" | bc -l)))
then
  flag=3
  max=$accuracy
fi
output=$(.././svm-train -t 2 -g $gammau -c $tradeoffu -v 10 -q svm_dataset/spam_train_std.txt)
tmp=${output#*= }
accuracy=${tmp%\%*}
if (($(echo "$accuracy>$max" | bc -l)))
then
  flag=4
  max=$accuracy
fi

case "$flag" in
  1)  lowergamma=$gammad
      uppergamma=$optimalgamma
      lowertrade=$tradeoffd
      uppertrade=$optimaltradeoff
      ;;
  2)  lowergamma=$optimalgamma
      uppergamma=$gammau
      lowertrade=$tradeoffd
      uppertrade=$optimaltradeoff
      ;;
  3)  lowergamma=$gammad
      uppergamma=$optimalgamma
      lowertrade=$optimaltradeoff
      uppertrade=$tradeoffu
      ;;
  4)  lowergamma=$optimalgamma
      uppergamma=$gammau
      lowertrade=$optimaltradeoff
      uppertrade=$tradeoffu
      ;;
esac

function finesearchRBF {
  unset gammarange
  unset tradeoffrange
  increment1=$(echo "($2-$1)/$5" | bc -l)
  for ((i=0;i<=$5;i++))
    do
    gammarange[$i]=$(echo "$1+$increment1*$i" | bc -l)
  done

  increment2=$(echo "($4-$3)/$5" | bc -l)
  for ((i=0;i<$5;i++))
    do
    tradeoffrange[$i]=$(echo "$3+$increment2*$i" | bc -l)
  done

  ii=0
  max=0
  for i in "${gammarange[@]}"
    do
    jj=0
    ii=$(($ii+1))
    for j in "${tradeoffrange[@]}"
      do
      jj=$(($jj+1))
      output=$(.././svm-train -t 2 -g $i -c $j -v 10 -q svm_dataset/spam_train_std.txt)
      tmp=${output#*= }
      accuracy=${tmp%\%*}
      printf "C: %1.10f G: %1.10f Accuracy: %2.1f%%\n" $j $i $accuracy
      if (($(echo "$accuracy>$max" | bc -l)))
      then
        max=$accuracy
        optimalgamma=$i
        optimaltradeoff=$j
        if (($ii<$5))
        then
          gammau=${gammarange[$ii+1]}
        else
          gammau=${gammarange[$ii]}
        fi
        if (($jj<$5))
        then
          tradeoffu=${tradeoffrange[$jj+1]}
        else
          tradeoffu=${tradeoffrange[$jj]}
        fi
        if (($ii>0))
        then
          gammad=${gammarange[$ii-1]}
        else
          gammad=${gammarange[$ii]}
        fi
        if (($jj>0))
        then
          tradeoffd=${tradeoffrange[$jj-1]}
        else
          tradeoffd=${tradeoffrange[$jj]}
        fi
      fi
    done
  done

  max=0
  output=$(.././svm-train -t 2 -g $gammad -c $tradeoffd -v 10 -q svm_dataset/spam_train_std.txt)
  tmp=${output#*= }
  accuracy=${tmp%\%*}
  if (($(echo "$accuracy>$max" | bc -l)))
  then
    flag=1
    max=$accuracy
  fi
  output=$(.././svm-train -t 2 -g $gammau -c $tradeoffd -v 10 -q svm_dataset/spam_train_std.txt)
  tmp=${output#*= }
  accuracy=${tmp%\%*}
  if (($(echo "$accuracy>$max" | bc -l)))
  then
    flag=2
    max=$accuracy
  fi
  output=$(.././svm-train -t 2 -g $gammad -c $tradeoffu -v 10 -q svm_dataset/spam_train_std.txt)
  tmp=${output#*= }
  accuracy=${tmp%\%*}
  if (($(echo "$accuracy>$max" | bc -l)))
  then
    flag=3
    max=$accuracy
  fi
  output=$(.././svm-train -t 2 -g $gammau -c $tradeoffu -v 10 -q svm_dataset/spam_train_std.txt)
  tmp=${output#*= }
  accuracy=${tmp%\%*}
  if (($(echo "$accuracy>$max" | bc -l)))
  then
    flag=4
    max=$accuracy
  fi

  case "$flag" in
    1)  lowergamma=$gammad
        uppergamma=$optimalgamma
        lowertrade=$tradeoffd
        uppertrade=$optimaltradeoff
        ;;
    2)  lowergamma=$optimalgamma
        uppergamma=$gammau
        lowertrade=$tradeoffd
        uppertrade=$optimaltradeoff
        ;;
    3)  lowergamma=$gammad
        uppergamma=$optimalgamma
        lowertrade=$optimaltradeoff
        uppertrade=$tradeoffu
        ;;
    4)  lowergamma=$optimalgamma
        uppergamma=$gammau
        lowertrade=$optimaltradeoff
        uppertrade=$tradeoffu
        ;;
  esac

}

accuracyf=0
old=-1
while (($(echo "$old<$accuracyf" | bc -l)))
do
  echo -e Performing finesearch between \n G: $lowergamma and $uppergamma C: $lowertrade and $uppertrade
  finesearchRBF $lowergamma $uppergamma $lowertrade $uppertrade 4
  param1=$optimalgamma
  param2=$optimaltradeoff
  output=$(.././svm-train -t 2 -g $param1 -c $param2 -v 10 -q svm_dataset/spam_train_std.txt)
  tmp=${output#*= }
  old=$accuracyf
  accuracyf=${tmp%\%*}
done

printf "Tuned values, for G: %1.10f, for C: %1.10f, related accuracy: %2.1f%%\n" $param1 $param2 $accuracyf

printf -v res %20s
printf '%s\n' "${res// /-}"
echo Polynomial Kernel

max=0

unset gammarange
unset tradeoffrange

for ((i=-10;i<4;i=$i+2))
  do
  coefprange[(($i+10))/2]=$(echo "2^$i" | bc -l)
done

for ((i=-10;i<4;i=$i+2))
  do
  gammarange[(($i+10))/2]=$(echo "2^$i" | bc -l)
done

for ((i=-6;i<4;i=$i+2))
  do
  tradeoffrange[(($i+6))/2]=$(echo "2^$i" | bc -l)
done

for ((d=1; d<=4; d++))
do
  ii=0
  for i in "${gammarange[@]}"
    do
    jj=0
    for j in "${tradeoffrange[@]}"
      do
      pp=0
      for p in "${coefprange[@]}"
        do
        output=$(.././svm-train -t 1 -d $d -g $i -r $p -c $j -v 10 -q svm_dataset/spam_train_std.txt)
        tmp=${output#*= }
        accuracy=${tmp%\%*}
        printf "P: %1.10f D: %d C: %1.10f G: %1.10f Accuracy: %2.1f%%\n" $p $d $j $i $accuracy
        if (($(echo "$accuracy>$max" | bc -l)))
        then
          max=$accuracy
          optimalgamma=$i
          optimaltradeoff=$j
          optimaldegree=$d
          optimalcoefp=$p
          if (($ii<6))
          then
            gammau=${gammarange[$ii+1]}
          else
            gammau=${gammarange[$ii]}
          fi
          if (($jj<4))
          then
            tradeoffu=${tradeoffrange[$jj+1]}
          else
            tradeoffu=${tradeoffrange[$jj]}
          fi
          if (($pp<6))
          then
            coefpu=${coefprange[$pp+1]}
          else
            coefpu=${coefprange[$pp]}
          fi
          if (($ii>0))
          then
            gammad=${gammarange[$ii-1]}
          else
            gammad=${gammarange[$ii]}
          fi
          if (($jj>0))
          then
            tradeoffd=${tradeoffrange[$jj-1]}
          else
            tradeoffd=${tradeoffrange[$jj]}
          fi
          if (($pp>0))
          then
            coefpd=${coefprange[$pp-1]}
          else
            coefpd=${coefprange[$pp]}
          fi
        fi
        pp=$(($pp+1))
      done
      jj=$(($jj+1))
    done
    ii=$(($ii+1))
  done
done

max=0
output=$(.././svm-train -t 1 -d $optimaldegree -g $gammad -r $coefpd -c $tradeoffd -v 10 -q svm_dataset/spam_train_std.txt)
tmp=${output#*= }
accuracy=${tmp%\%*}
if (($(echo "$accuracy>$max" | bc -l)))
then
  flag=1
  max=$accuracy
fi
output=$(.././svm-train -t 1 -d $optimaldegree -g $gammau -r $coefpd -c $tradeoffd -v 10 -q svm_dataset/spam_train_std.txt)
tmp=${output#*= }
accuracy=${tmp%\%*}
if (($(echo "$accuracy>$max" | bc -l)))
then
  flag=2
  max=$accuracy
fi
output=$(.././svm-train -t 1 -d $optimaldegree -g $gammad -r $coefpd -c $tradeoffu -v 10 -q svm_dataset/spam_train_std.txt)
tmp=${output#*= }
accuracy=${tmp%\%*}
if (($(echo "$accuracy>$max" | bc -l)))
then
  flag=3
  max=$accuracy
fi
output=$(.././svm-train -t 1 -d $optimaldegree -g $gammau -r $coefpd -c $tradeoffu -v 10 -q svm_dataset/spam_train_std.txt)
tmp=${output#*= }
accuracy=${tmp%\%*}
if (($(echo "$accuracy>$max" | bc -l)))
then
  flag=4
  max=$accuracy
fi
output=$(.././svm-train -t 1 -d $optimaldegree -g $gammad -r $coefpu -c $tradeoffd -v 10 -q svm_dataset/spam_train_std.txt)
tmp=${output#*= }
accuracy=${tmp%\%*}
if (($(echo "$accuracy>$max" | bc -l)))
then
  flag=5
  max=$accuracy
fi
output=$(.././svm-train -t 1 -d $optimaldegree -g $gammau -r $coefpu -c $tradeoffd -v 10 -q svm_dataset/spam_train_std.txt)
tmp=${output#*= }
accuracy=${tmp%\%*}
if (($(echo "$accuracy>$max" | bc -l)))
then
  flag=6
  max=$accuracy
fi
output=$(.././svm-train -t 1 -d $optimaldegree -g $gammad -r $coefpu -c $tradeoffu -v 10 -q svm_dataset/spam_train_std.txt)
tmp=${output#*= }
accuracy=${tmp%\%*}
if (($(echo "$accuracy>$max" | bc -l)))
then
  flag=7
  max=$accuracy
fi
output=$(.././svm-train -t 1 -d $optimaldegree -g $gammau -r $coefpu -c $tradeoffu -v 10 -q svm_dataset/spam_train_std.txt)
tmp=${output#*= }
accuracy=${tmp%\%*}
if (($(echo "$accuracy>$max" | bc -l)))
then
  flag=8
  max=$accuracy
fi

case "$flag" in
  1)  lowergamma=$gammad
      uppergamma=$optimalgamma
      lowertrade=$tradeoffd
      uppertrade=$optimaltradeoff
      lowercoefp=$coefpd
      uppercoefp=$optimalcoefp
      ;;
  2)  lowergamma=$optimalgamma
      uppergamma=$gammau
      lowertrade=$tradeoffd
      uppertrade=$optimaltradeoff
      lowercoefp=$coefpd
      uppercoefp=$optimalcoefp
      ;;
  3)  lowergamma=$gammad
      uppergamma=$optimalgamma
      lowertrade=$optimaltradeoff
      uppertrade=$tradeoffu
      lowercoefp=$coefpd
      uppercoefp=$optimalcoefp
      ;;
  4)  lowergamma=$optimalgamma
      uppergamma=$gammau
      lowertrade=$optimaltradeoff
      uppertrade=$tradeoffu
      lowercoefp=$coefpd
      uppercoefp=$optimalcoefp
      ;;
  5)  lowergamma=$gammad
      uppergamma=$optimalgamma
      lowertrade=$tradeoffd
      uppertrade=$optimaltradeoff
      lowercoefp=$optimalcoefp
      uppercoefp=$coefpu
      ;;
  6)  lowergamma=$optimalgamma
      uppergamma=$gammau
      lowertrade=$tradeoffd
      uppertrade=$optimaltradeoff
      lowercoefp=$optimalcoefp
      uppercoefp=$coefpu
      ;;
  7)  lowergamma=$gammad
      uppergamma=$optimalgamma
      lowertrade=$optimaltradeoff
      uppertrade=$tradeoffu
      lowercoefp=$optimalcoefp
      uppercoefp=$coefpu
      ;;
  8)  lowergamma=$optimalgamma
      uppergamma=$gammau
      lowertrade=$optimaltradeoff
      uppertrade=$tradeoffu
      lowercoefp=$optimalcoefp
      uppercoefp=$coefpu
      ;;
esac

function finesearchPln {
  unset coefprange
  unset gammarange
  unset tradeoffrange
  increment1=$(echo "($2-$1)/$7" | bc -l)
  for ((i=0;i<=$7;i++))
    do
    gammarange[$i]=$(echo "$1+$increment1*$i" | bc -l)
  done

  increment2=$(echo "($4-$3)/$7" | bc -l)
  for ((i=0;i<=$7;i++))
    do
    tradeoffrange[$i]=$(echo "$3+$increment2*$i" | bc -l)
  done

  increment3=$(echo "($6-$5)/$7" | bc -l)
  for ((i=0;i<=$7;i++))
    do
    coefprange[$i]=$(echo "$5+$increment3*$i" | bc -l)
  done

  ii=0
  for i in "${gammarange[@]}"
    do
    jj=0
    for j in "${tradeoffrange[@]}"
      do
      pp=0
      for p in "${coefprange[@]}"
        do
        output=$(.././svm-train -t 1 -d $optimaldegree -g $i -r $p -c $j -v 10 -q svm_dataset/spam_train_std.txt)
        tmp=${output#*= }
        accuracy=${tmp%\%*}
        printf "P: %1.10f D: %d C: %1.10f G: %1.10f Accuracy: %2.1f%%\n" $p $optimaldegree $j $i $accuracy
        if (($(echo "$accuracy>$max" | bc -l)))
        then
          max=$accuracy
          optimalgamma=$i
          optimaltradeoff=$j
          optimalcoefp=$p
          if (($ii<$7))
          then
            gammau=${gammarange[$ii+1]}
          else
            gammau=${gammarange[$ii]}
          fi
          if (($jj<$7))
          then
            tradeoffu=${tradeoffrange[$jj+1]}
          else
            tradeoffu=${tradeoffrange[$jj]}
          fi
          if (($pp<$7))
          then
            coefpu=${coefprange[$pp+1]}
          else
            coefpu=${coefprange[$pp]}
          fi
          if (($ii>0))
          then
            gammad=${gammarange[$ii-1]}
          else
            gammad=${gammarange[$ii]}
          fi
          if (($jj>0))
          then
            tradeoffd=${tradeoffrange[$jj-1]}
          else
            tradeoffd=${tradeoffrange[$jj]}
          fi
          if (($pp>0))
          then
            coefpd=${coefprange[$pp-1]}
          else
            coefpd=${coefprange[$pp]}
          fi
        fi
        pp=$(($pp+1))
      done
      jj=$(($jj+1))
    done
    ii=$(($ii+1))
  done

  max=0
  output=$(.././svm-train -t 1 -d $optimaldegree -g $gammad -r $coefpd -c $tradeoffd -v 10 -q svm_dataset/spam_train_std.txt)
  tmp=${output#*= }
  accuracy=${tmp%\%*}
  if (($(echo "$accuracy>$max" | bc -l)))
  then
    flag=1
    max=$accuracy
  fi
  output=$(.././svm-train -t 1 -d $optimaldegree -g $gammau -r $coefpd -c $tradeoffd -v 10 -q svm_dataset/spam_train_std.txt)
  tmp=${output#*= }
  accuracy=${tmp%\%*}
  if (($(echo "$accuracy>$max" | bc -l)))
  then
    flag=2
    max=$accuracy
  fi
  output=$(.././svm-train -t 1 -d $optimaldegree -g $gammad -r $coefpd -c $tradeoffu -v 10 -q svm_dataset/spam_train_std.txt)
  tmp=${output#*= }
  accuracy=${tmp%\%*}
  if (($(echo "$accuracy>$max" | bc -l)))
  then
    flag=3
    max=$accuracy
  fi
  output=$(.././svm-train -t 1 -d $optimaldegree -g $gammau -r $coefpd -c $tradeoffu -v 10 -q svm_dataset/spam_train_std.txt)
  tmp=${output#*= }
  accuracy=${tmp%\%*}
  if (($(echo "$accuracy>$max" | bc -l)))
  then
    flag=4
    max=$accuracy
  fi
  output=$(.././svm-train -t 1 -d $optimaldegree -g $gammad -r $coefpu -c $tradeoffd -v 10 -q svm_dataset/spam_train_std.txt)
  tmp=${output#*= }
  accuracy=${tmp%\%*}
  if (($(echo "$accuracy>$max" | bc -l)))
  then
    flag=5
    max=$accuracy
  fi
  output=$(.././svm-train -t 1 -d $optimaldegree -g $gammau -r $coefpu -c $tradeoffd -v 10 -q svm_dataset/spam_train_std.txt)
  tmp=${output#*= }
  accuracy=${tmp%\%*}
  if (($(echo "$accuracy>$max" | bc -l)))
  then
    flag=6
    max=$accuracy
  fi
  output=$(.././svm-train -t 1 -d $optimaldegree -g $gammad -r $coefpu -c $tradeoffu -v 10 -q svm_dataset/spam_train_std.txt)
  tmp=${output#*= }
  accuracy=${tmp%\%*}
  if (($(echo "$accuracy>$max" | bc -l)))
  then
    flag=7
    max=$accuracy
  fi
  output=$(.././svm-train -t 1 -d $optimaldegree -g $gammau -r $coefpu -c $tradeoffu -v 10 -q svm_dataset/spam_train_std.txt)
  tmp=${output#*= }
  accuracy=${tmp%\%*}
  if (($(echo "$accuracy>$max" | bc -l)))
  then
    flag=8
    max=$accuracy
  fi

  case "$flag" in
    1)  lowergamma=$gammad
        uppergamma=$optimalgamma
        lowertrade=$tradeoffd
        uppertrade=$optimaltradeoff
        lowercoefp=$coefpd
        uppercoefp=$optimalcoefp
        ;;
    2)  lowergamma=$optimalgamma
        uppergamma=$gammau
        lowertrade=$tradeoffd
        uppertrade=$optimaltradeoff
        lowercoefp=$coefpd
        uppercoefp=$optimalcoefp
        ;;
    3)  lowergamma=$gammad
        uppergamma=$optimalgamma
        lowertrade=$optimaltradeoff
        uppertrade=$tradeoffu
        lowercoefp=$coefpd
        uppercoefp=$optimalcoefp
        ;;
    4)  lowergamma=$optimalgamma
        uppergamma=$gammau
        lowertrade=$optimaltradeoff
        uppertrade=$tradeoffu
        lowercoefp=$coefpd
        uppercoefp=$optimalcoefp
        ;;
    5)  lowergamma=$gammad
        uppergamma=$optimalgamma
        lowertrade=$tradeoffd
        uppertrade=$optimaltradeoff
        lowercoefp=$optimalcoefp
        uppercoefp=$coefpu
        ;;
    6)  lowergamma=$optimalgamma
        uppergamma=$gammau
        lowertrade=$tradeoffd
        uppertrade=$optimaltradeoff
        lowercoefp=$optimalcoefp
        uppercoefp=$coefpu
        ;;
    7)  lowergamma=$gammad
        uppergamma=$optimalgamma
        lowertrade=$optimaltradeoff
        uppertrade=$tradeoffu
        lowercoefp=$optimalcoefp
        uppercoefp=$coefpu
        ;;
    8)  lowergamma=$optimalgamma
        uppergamma=$gammau
        lowertrade=$optimaltradeoff
        uppertrade=$tradeoffu
        lowercoefp=$optimalcoefp
        uppercoefp=$coefpu
        ;;
  esac

}


accuracyf=0
old=-1
while (($(echo "$old<$accuracyf" | bc -l)))
do
  echo -e Performing finesearch between "\n"G: $lowergamma and $uppergamma "\n"P: $lowercoefp and $uppercoefp "\n"C: $lowertrade and $uppertrade
  finesearchPln $lowergamma $uppergamma $lowertrade $uppertrade $lowercoefp $uppercoefp 4
  param1=$optimalgamma
  param2=$optimaltradeoff
  param3=$optimalcoefp
  output=$(.././svm-train -t 1 -d $optimaldegree -g $param1 -r $param3 -c $param2 -v 10 -q svm_dataset/spam_train_std.txt)
  tmp=${output#*= }
  old=$accuracyf
  accuracyf=${tmp%\%*}
done

printf "Tuned values, for D: %d, for P: %1.10f, for G: %1.10f, for C: %1.10f, related accuracy: %2.1f%%\n" $optimaldegree $param3 $param1 $param2 $accuracyf
