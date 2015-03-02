/* queue suspend/resume protocol */

/* flags in the shared disk */
bool suspend /* suspend requested */
bool suspend_ack /* suspend acknowledged *.

/* the queue may have no data (none); a delta or a full sync.
   the full sync is performed immediately on resume. */
mtype = { sync delta none }
mtype inflight_data = none

proctype consumer(){

  do
  /* Consumer.pop */
  :: (inflight_data != none) ->
    /* In steady state we receive deltas */
    assert (suspend_ack == false);
    assert (inflight_data == delta);
    inflight_data = none
  /* Consumer.suspend */
  :: (suspend == false) ->
    suspend = true;
    /* ordering important here */
    (suspend_ack == true);
    inflight_data = none;
  /* Consumer.resume */
  :: (suspend == true) ->
    suspend = false;
    (suspend_ack == false)
    /* Wait for initial resync */
    (inflight_data == sync)
    inflight_data = none
  od;
}

proctype producer(){
  do
  /* Producer.state = Running */
  :: ((suspend == false)&&(suspend_ack==true)) ->
    suspend_ack = false;
    inflight_data = sync
  /* Producer.state = Suspended */
  :: ((suspend == true) && (suspend_ack == false)) ->
    suspend_ack = true
  /* Producer.push */
  :: ((suspend == false) && (suspend_ack == false) && (inflight_data != sync)) ->
    inflight_data = delta
  od
}

init {
  atomic {
    run producer();
    run consumer();
  }
}
