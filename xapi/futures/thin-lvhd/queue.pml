/* queue suspend/resume protocol */


mtype = { data, rst, dunno, one, two }

bool suspend
bool suspend_ack
bool inflight_data

proctype consumer(){
  printf("consumer")

  do
  :: (inflight_data == true) ->
    assert (suspend_ack == false);
    inflight_data = false
  :: (suspend == false) ->
    suspend = true;
    /* ordering important here */
    (suspend_ack == true);
    inflight_data = false;
  :: (suspend == true) ->
    suspend = false;
    (suspend_ack == false)
  od;
}

proctype producer(){
  printf("producer")
  do
  :: (suspend != suspend_ack) -> suspend_ack = suspend
  :: ((suspend == false) && (suspend_ack == false)) -> inflight_data = true
  od
}

init {
  atomic {
    run producer();
    run consumer();
  }
}
