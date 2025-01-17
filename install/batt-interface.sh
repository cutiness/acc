idle_discharging() {
  [ $curThen != null ] && [ ${curNow#-} -le $idleThreshold ] && _status=Idle || {
    [ $_status != Discharging ] || return 0
    case "${dischargePolarity-}" in
      +) [ $curNow -ge 0 ] && _status=Discharging || _status=Charging;;
      -) [ $curNow -lt 0 ] && _status=Discharging || _status=Charging;;
      *) [ $curThen = null ] || {
           tt "$curThen,$curNow" "-*,[0-9]*|[0-9]*,-*" && _status=Discharging || _status=Charging
         };;
    esac
  }
}


not_charging() {

  local i=
  local switch=${flip-}; flip=
  local curThen=$(cat $curThen)
  #local seqDrop=${seqDrop:-5}
  local seqOff=${seqOff:-16}
  local seqOn=${seqOn:-30}
  local battStatusOverride="${battStatusOverride-}"
  local battStatusWorkaround=${battStatusWorkaround-}

  tt "${chargingSwitch[$*]-}" "*\ --" || battStatusOverride=
  [ $currFile != $TMPDIR/.dummy-curr ] || battStatusWorkaround=false

  if [ -z "${battStatusOverride-}" ] && [ "$switch" = off ]; then
    for i in $(seq $seqOff); do
      ! status ${1-} || return 0
      # if $battStatusWorkaround && [ $i -ge $seqDrop ]; then
      #   case "${dischargePolarity-}" in
      #     +) [ $(cat $currFile) -gt $((curThen / 100 * 90)) ] || return 1;;
      #     -) [ $(cat $currFile) -lt $((curThen / 100 * 90)) ] || return 1;;
      #   esac
      # fi
      [ $i = $seqOff ] || sleep 1
    done
    return 1
  else
    if ! ${isAccd:-false} && [ "$switch" = on ]; then
      for i in $(seq $seqOn); do
        status ${1-} || return 1
        [ $i = $seqOn ] || sleep 1
      done
    else
      status ${1-}
    fi
  fi
}


online() {
  grep 1 */online | grep -iv bms >/dev/null
}


read_status() {
  local status="$(cat $battStatus)"
  case "$status" in
    Charging|Discharging) printf %s $status;;
    Not?charging) printf Idle;;
    *) printf Discharging;;
  esac
}


status() {

  local i=
  local curNow=$(cat $currFile)

  _status=$(read_status)

  [ -z "${exitCode_-}" ] || echo "  switch:${switch:-on} status:$_status curr:$curThen,$curNow"

  if [ -n "${battStatusOverride-}" ]; then
    if tt "$battStatusOverride" "Discharging|Idle"; then
      [ $(cat ${chargingSwitch[0]}) != ${chargingSwitch[2]} ] || _status=$battStatusOverride
    else
      _status=$(set -eu; eval '$battStatusOverride') || :
    fi
  elif $battStatusWorkaround; then
    [ $_status = Idle ] || idle_discharging
  fi

  for i in Discharging DischargingDischarging Idle IdleIdle; do
    [ $i != ${1-}$_status ] || return 0
  done

  return 1
}


if ${init:-false}; then

  for batt in maxfg/capacity */capacity; do
    if [ -f ${batt%/*}/status ]; then
      batt=${batt%/*}
      break
    fi
  done

  case $batt in
    */capacity) exit 1;;
  esac

  for battStatus in sm????_bms/status $batt/status; do
    [ ! -f $battStatus ] || break
  done


  echo 250 > $TMPDIR/.dummy-temp

  for temp in $batt/temp $batt/batt_temp bms/temp $TMPDIR/.dummy-temp; do
    [ ! -f $temp ] || break
  done


  echo 0 > $TMPDIR/.dummy-curr

  for currFile in $batt/current_now bms/current_now \
    $batt/batteryaveragecurrent $TMPDIR/.dummy-curr
  do
    [ ! -f $currFile ] || break
  done

  idleThreshold=95 # mA
  ampFactor=$(sed -n 's/^ampFactor=//p' $dataDir/config.txt 2>/dev/null || :)
  ampFactor_=${ampFactor:-1000}

  if [ $ampFactor_ -eq 1000000 ] || [ $(sed s/-// $currFile) -ge 16000 ]; then
    ampFactor_=1000000
    idleThreshold=${idleThreshold}000
  fi

  curThen=$TMPDIR/.curr
  rm $curThen 2>/dev/null || :


  echo "
ampFactor_=$ampFactor_
batt=$batt
battCapacity=$batt/capacity
battStatus=$battStatus
currFile=$currFile
curThen=$curThen
idleThreshold=$idleThreshold
temp=$temp
" > $TMPDIR/.batt-interface.sh

  init=false

else
  . $TMPDIR/.batt-interface.sh
fi

[ -f $curThen ] || echo null > $curThen
