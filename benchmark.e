OPT MODULE
OPT EXPORT


MODULE 'timer'
MODULE 'devices/timer'
MODULE 'exec/io'


OBJECT benchmark
    tr:PTR TO timerequest
    timer_device_open:LONG
    num_marks:LONG
    mark_ctr:LONG
    start_time:PTR TO timeval
    end_time:PTR TO timeval
ENDOBJECT

PROC init(num_marks:LONG) OF benchmark
    IF OpenDevice('timer.device', UNIT_MICROHZ, self.tr, 0) = 0
        self.timer_device_open := TRUE
        timerbase := self.tr.io.device
    ELSE
        Raise("TIME")
    ENDIF
    self.num_marks := num_marks
    self.mark_ctr := 0
    NEW self.start_time
    NEW self.end_time[num_marks]
ENDPROC

PROC end() OF benchmark
    IF self.timer_device_open THEN CloseDevice(self.tr)
    END self.start_time
    END self.end_time[self.num_marks]
ENDPROC

-> Start the benchmark timer.
PROC start() OF benchmark
    GetSysTime(self.start_time)
ENDPROC

-> Stop the benchmark timer.
PROC mark() OF benchmark
    GetSysTime(self.end_time[self.mark_ctr])
    self.mark_ctr := self.mark_ctr + 1
ENDPROC

-> Return the time delta as milliseconds. Overflows after around 24 days.
PROC msecs(mark:LONG) OF benchmark
    DEF ms_start
    DEF ms_end
    
    ms_start := Mul(self.start_time.secs, 1000) + Div(self.start_time.micro, 1000)
    ms_end := Mul(self.end_time[mark].secs, 1000) + Div(self.end_time[mark].micro, 1000)
ENDPROC ms_end - ms_start

-> Return the time delta as microseconds. Overflows after 2147 seconds.
PROC usecs(mark:LONG) OF benchmark
    DEF us_start
    DEF us_end
    
    us_start := Mul(self.start_time.secs, 1000000) + self.start_time.micro
    us_end := Mul(self.end_time[mark].secs, 1000000) + self.end_time[mark].micro
ENDPROC us_end - us_start
