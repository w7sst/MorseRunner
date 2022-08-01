#/bin/bash -v

for a in df9ts f6fvy n2ic bh1scw jr8ppg zmetzing;
do
  echo "---------------------------------"
  echo "---- $a -------------------"
  readarray -t normalized <<< $(git rev-list --abbrev-commit ve3nea-normalized...$a-normalized);
  readarray -t master <<< $(git rev-list --abbrev-commit ve3nea-start...$a-master);
  for (( i=0; i < ${#normalized[@]}; i++));
  do
    git log --oneline -1 ${master[i]}
    git log --oneline -1 ${normalized[i]}
    git diff --name-only ${master[i]} ${normalized[i]} | grep -v -e MorseRunner.exe -e MorseRunner.ini -e MorseRunner.res -e Main.lrs -e VCL/VolmSldr.dcr -e VCL/VolumCtl.dcr -e .gitattributes -e .gitignore -e dcu -e Runner.stat -e Runner.identcache -e Runner.lps -e Runner.dproj.local -e __history | xargs git diff -w --histogram --compact-summary ${master[i]} ${normalized[i]} --
    git diff main ${normalized[i]} -- .gitattributes .gitignore
    echo "-------------------------"
  done
done
