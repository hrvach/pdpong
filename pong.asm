pong game, v1.2 written by Hrvoje Cavrak, 02/2019

	szm=sza sma-szf	

define swap
	rcl 9s					/ Swap AC and IO registers macro
	rcl 9s				
	terminate


define  point A, B				/ Draw a point at (x+A, y+B) 
	law B
	add y
	sal 8s

	swap

	law A
	add x
	sal 8s

	dpy-i +300
	terminate

						/ Ball consists of 8 points
define  circle
	point 0, 1				/ 50 us between successive calls, it's ok to 
	point 0, 3				/ use without waiting on completion pulse
	
	point 4, 1
	point 4, 3

	point 1, 0
	point 1, 3
	
	point 1, 4
	point 3, 4

	terminate

define paddle X, Y				/ Draws paddles
	lac pdlwidth
	cma
	dac p1cnt
pdloop,
	lac Y
	add pdlwidth
	add p1cnt
	sal 8s

	swap

	lac X
	dpy-i+300

	law 6
	add p1cnt
	dac p1cnt
	isp p1cnt

	jmp pdloop+R
	terminate

define line C, D				/ Central line which acts as the "net"
 	law 0	
	sub maxdown 
	sub maxdown 
	dac p1cnt

ploop2,
	lac p1cnt
	add maxdown 
	sal 9s

	swap
	law D
	dpy-i
	
	law 70 					
	add p1cnt
	dac p1cnt

	isp p1cnt
	jmp ploop2+R
	terminate


0/	opr
	opr
	opr
	opr
	jmp init				/ Jump to the init routine


400/
init,
	dzm p1score
	dzm p2score
	
	dzm x
	dzm y

	dzm pdl1y
	dzm pdl2y

	jsp prec	
	jmp loop

500/
loop,  						/ Main loop start 
	lac timer				/ If the timer is negative, proceed to increment it and skip over
	sma					/ the part where ball and paddles are drawn (between games)
	jmp lpskip

	idx timer				/ Increment the wait timer and don't draw ball and paddles
	jmp wait

lpskip,
	circle					/ Draw the ball
	lac x
	add dx					/ Add the x delta to the ball position
	dac x					/ Store the x back to memory

	jsp checkx				/ Jump to subroutine which checks permitted x position

	lac y
	add dy					/ Add the y delta to the ball position
	dac y					/ Store the y back to memory

	jsp checky				/ Jump to subroutine which checks permitted y position
	
	jsp rnd					/ Update the random number generator
	
wait,	
	jsp move				/ Invoke the paddle moving routine

	paddle left, pdl1y			/ Invoke the paddle drawing routine
	paddle right, pdl2y

	jsp co1					/ Draw score using compiled code, left player
	jsp co2					/ right player

	line 0, 0				/ Draw the net
	
	jmp loop

rnd,    dap rret				/ Spacewar's random generator
	lac random
	rar 1s

	xor (355670
	add (355670
	dac random				/ It's also altered by user input, so it's user + prng

rret,   jmp .


define  noc X					/ Number outline compiler
	lac X
	dac i cptr
	idx cptr
	terminate

cx,     000000					/ Initial X position
cy1,	000360					/ Initial Y position

prec,	dap pc1r
	law co1 1
	dac cptr	
	
	lac (n1dots
	add p1score
	dac \index

	law 200
	dac cx

	jsp jit					/ Render digit for player 1
	noc (jmp cr1

	/ -------------- Player 2 --------------
	law co2 1
	dac cptr	

	lac (n2dots
	add p2score
	dac \index
	
	law 201
	dac cx

	jsp jit
	noc (jmp cr2

pc1r,	jmp .


jit,	dap jret				/ compiler routine, generates time-sensitive display 
						/ writing code so digits can be displayed and still game without flicker
	lac i \index
	
	cma					/ Complement it, so we can use spi to skip on 0
	swap					/ Move it to IO register
	
	lac cx					/ Load initial X position
	dac crow				/ Store it in X position pointer

	lac cy1					/ Load initial Y position
	dac ccol				/ Store it in Y position pointer

jlp,
	rir 1s					/ Rotate IO left
	
	spi					/ Skip if bit is 1
	jsp nodot

	lac (law				/ Generate code to generate dots
	add ccol

	dac i cptr
	idx cptr

	noc (sal 9s
	noc (rcr 9s
	noc (rcr 9s

	lac (law 
	add crow	

	dac i cptr 
	idx cptr

	noc (nop				/ Timing budget between DPYs
	noc (nop				/ law (5us), shift (5us), rotate (5us)
	noc (nop				/ rotate (5us), law (5us), shift (5us), opr (5us)
	noc (nop				/ = 35 us, we need 50 us so insert 4 more nops just to be safe
						/ completion pulse not needed
	noc (sal 8s
	
	lac cx
	and (1
	sza
	jmp sd1					/ NOC macro is 3 instructions, jump over it if cma not needed 

	noc (cma				/ If negative, complement accumulator in compiled code
	
	
sd1,	noc (dpy -i +300
nodot,	
	law 10					/ Load X step
	add crow				/ Add to current X position
	dac crow				/ Store back into memory

	lac cx
	add (30

	sas crow				/ If we reached the end of row
	jmp nd2skp				/ Skip the next statements
	
	lac cx					/ Reset X position to start of row
	dac crow

	lac ccol				/ Move down to next row
	sub (4
	dac ccol

nd2skp,	
	lac cy1					/ Load bottom row
	sub (24
	sas ccol				/ Skip if current row equals bottom row 
	jmp jlp					/ Repeat loop

jret,	jmp .


define testkey K, N				/ Tests if key K was pressed and skips to N if it is not
	lac controls
	and K
	sza
	jmp N
	terminate

define padmove Y, A				/ Initiates moving of the pads
	lac Y
	dac pdly
	jsp A
	lac pdly
	dac Y
	terminate


move,
	dap mvret				/ Moves the paddles
	cli					/ Load current controller button state
	iot 11
	dio controls

move1,
	testkey rghtup, move2			/ Right UP
	padmove pdl2y, mvup

move2,
	testkey leftup, move3			/ Left UP
	padmove pdl1y, mvup

move3,						/ Right DOWN
	testkey rghtdown, move4
	padmove pdl2y, mvdown

move4,						/ Left DOWN
	testkey leftdown, mvret
	padmove pdl1y, mvdown

mvret,  jmp .


define flip A					/ Inverts the bits of memory location A
	lac A
	cma
	dac A
	terminate


mvup,	dap upret				/ Move pad UP
	lac pdly
	sub limitup				/ Check if pad at top edge
	sma
	jmp upret				/ Do nothing if it is
	lac pdly
	add padoff
	dac pdly

	add random				/ Use pad coordinates as user provided randomness
	dac random
upret, jmp .

mvdown,	dap downret				/ Move pad DOWN
	lac pdly
	add limitdown				/ Check if pad at bottom edge
	spa
	jmp downret				/ Do nothing if it is
	lac pdly
	sub padoff
	dac pdly
	
	add random				/ Use pad coordinates as user provided randomness
	dac random
downret, jmp .


delay,  dap dlyret				/ Delay routine
	lac dlytime
	dac dlycnt
dlyloop,
	isp dlycnt
	jmp dlyloop
dlyret, jmp .


gmovr,						/ Game over routine
	lac (777000				/ Long pause after game is over
	dac timer
	jmp init				/ Init won't re-set the timer so the game will pause for a while

srvover, 					/ Serve was lost
	lac dx				
	dac whowon				/ Store who won last serve

	sma					/ If dx was positive, the ball was going right and player 2 (right) lost
	idx p1score

	lac whowon
	spa					/ Else, player 1 (left) lost
	idx p2score

	jsp prec				/ Call compiler to recompute the routines for drawing digits	

	lac (777650				/ Short pause between ball launches
	dac timer
	
	lac p1score				/ Did player 1 win the game?
	sub (12
	sma
	jmp gmovr				/ If so, go to game over 

	lac p2score				/ Did player 2 win the game?
	sub (12
	sma
	jmp gmovr 				/ If true, jump to game over

	jmp restart				/ Nobody won yet, jump to serve another ball


restart,
	jsp delay				/ Wait a bit before serving
	idx iter				/ Count the number of restarts

	lac random				/ Load the current randomness value
	and dymask				/ Limit it to the interval we need it to be
	add (1					/ Don't want it to be 0
	dac dy					/ Set initial launch vector to this value

	lac random
	and ymask
	sub maxdown
	dac y					/ Do the same for launch position
	
	law 2					/ Set initial launch vector
	lio whowon
	spi					/ Skip complementing depending on who won last round
	cma					/ Therefore, the ball will be launched towards the loser
	dac dx					/ of the previous round
	
	law 600					/ Set X coordinate of ball to serve
	cma

	spi					/ If serve was won by player 1, complement so it's left of the net
	cma

	dac x	
	jmp ckret


hitpaddle, dap ckret				/ Check for colision with paddle
	lac y
	sub pdly
	add (1
	spa					/ must be true: y - pdl1y > 0
	jmp srvover				/ return if not

	sub pdlwidth
	sub (2					/ tweak borders so edges are not registered as a miss
	sma					/ must be true: y - pdlwidth - pdl1y < 0
	jmp srvover				/ return if not

	flip dx
	idx dirchng				/ Count number of paddle hits, increase speed subsequently

	lac dx
	spa
	jmp skipfast				/ Consider increasing dx only if positive

	law 3					/ if 3 - dirchng < 0 (every 3 hits from right paddle), increase speed 
	sub dirchng
	spa
	idx dx 
	spa
	dzm dirchng				/ Reset dirchng counter back to zero, everything starts from scratch

skipfast,
	lac pdly				/ get distance from center of paddle
	add pdlhalf
	sub y

	spa
	cma					/ take abs() of accumulator
	sar 4s					/ shift 3 bits right (divide by 8)
	add (1					/ To prevent x-only movement, add 1 so it should never be zero

	/ Here, accumulator holds the absolute offset from the paddle center divided by 8

	lio dy					/ Load dy to IO not to destroy ACC contents
	spi					/ If dy is positive, subtract
	cma

	dac dy					/ Set new y bounce angle
	
ckret,  jmp .


checkx,
	dap cxret
	lac pdl1y				/ Load position of right paddle
	dac pdly
	lac x
	add maxleft				/ AC = x + maxright, if x < -500, swap dx
	spa
	jsp hitpaddle

	lac pdl2y				/ Load position of left paddle
	dac pdly
	lac x
	sub maxright				/ AC = x - maxleft, if x > 500, swap dx
	sma
	jsp hitpaddle
cxret, jmp .


checky,
	dap cyret
	lac y
	add maxdown				/ AC = y + maxdown, if y < -500, swap dy
	spa
	jmp cnext
	flip dy

cnext,
	lac y
	sub maxdown				/ AC = y - maxdown, if y > 500, swap dy
	sma
	jmp cyret
	flip dy
cyret, jmp .




////////////////////////////////////////////////////////////////////////////////////////////////

x,		000500				/ Current ball coordinates
y,		000000

dx,		777775				/ Movement vector
dy,		000003

iter,		000000				/ Number of restarts

cptr,		000000				/ Current LUT compiler pointer
crow,		000000				/ Current row X position
ccol,		000000				/ Current row Y position

padoff, 	000004				/ Paddle offset
random,		000001				/ Randomness pool, changes via PRNG + user input

pdly,		000000				/ Paddle vertical position

pdl1y, 		000000				/ Paddle 1 vertical position
pdl2y, 		000000				/ Paddle 2 vertical position

p1cnt,	  	000000
controls, 	000000				/ Current state of input buttons

left, 		400400
right, 		374000

pdlwidth, 	000150				/ Width of a paddle
pdlhalf,  	000064				/ Half width

maxright,  	000764				/ Limit the X coordinate in right direction
maxleft,  	000774				/ Limit X coordinate left
maxdown,   	000764				/ Limit Y coordinate down

dymask,		000003				/ Anded with dymask, take only the last 2 bits
ymask,		000777				/ Anded with ymask, take only the last 9 bits

limitup,	000562				/ Top limit for the PAD position
limitdown,	000760				/ Bottom limit for the PAD position

leftdown,   	000001				/ Key bitmasks, left down
leftup,		000002				/ left up

rghtdown,	040000				/ Right down
rghtup,	 	100000				/ Right up

dlytime,	770000				/ Time to wait before launching the ball
dlycnt,		000000				/ Delay counter register
dirchng,	000000				/ Counts direction changes, used for increasing ball speed

p1score,	000000				/ Player 1's score
p2score,	000000				/ Player 2's score
whowon,		000000				/ Which player won last serve (>0 = right, <0 = left)

timer,		777700				/ Used to wait a while after game over

/ n1dots and n2dots are horizontally flipped

n1dots,		075557				/ 0
		011111				/ 1
		074717				/ 2
		071717				/ 3
		011755				/ 4
		071747				/ 5
		075744				/ 6
		011117				/ 7
		075757				/ 8
		011757				/ 9

n2dots,		075557				/ 0
		011111				/ 1
		071747				/ 2
		074747				/ 3
		044755				/ 4
		074717				/ 5
		075711				/ 6
		044447				/ 7
		075757				/ 8
		044757				/ 9

5670/
co1,	dap cr1	
	jmp cr1
	. 300/					/ Reserve space for number compilation, player 1
cr1,   jmp .

co2,	dap cr2	
	jmp cr2
	. 300/					/ Reserve space for number compilation, player 2
cr2,   jmp .

	constants
	variables

	start 400
