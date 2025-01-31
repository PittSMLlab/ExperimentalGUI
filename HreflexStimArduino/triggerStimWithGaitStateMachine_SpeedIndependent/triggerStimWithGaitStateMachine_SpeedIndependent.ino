// Code to stimulate the tibial nerve of both legs for the Spinal Adaptation
// study to measure H-reflexes during split-belt adaptation. Updated to
// accept Serial input from MATLAB to indicate whether to stimulate on the
// current stride. Includes the gait event detection state machine and
// removes speed dependence by storing the single stance duration of the
// previous two strides.
// date (started): 26 Mar. 2024
// date (updated): 18 Nov. 2024
// author(s): SL, NWB

// initialize variables to track gait events and phases
bool isCurrStanceL = false;            // is current step left foot stance?
bool isCurrStanceR = false;            // is current step right foot stance?
bool isPrevStanceL = false;            // is previous step left foot stance?
bool isPrevStanceR = false;            // is previous step right foot stance?
int freqStim = 1;                      // temporary stride frequency of stimulation for development
bool LHS = false;                      // is there a left heel strike event?
bool RHS = false;                      // is there a right heel strike event?
bool LTO = false;                      // is there a left toe off event?
bool RTO = false;                      // is there a right toe off event?
unsigned long timeLHS = 0;             // time of most recent LHS events
unsigned long timeRHS = 0;             // time of most recent RHS events
unsigned long timeLTO = 0;             // time of most recent LTO events
unsigned long timeRTO = 0;             // time of most recent RTO events
const int maxStrides = 1000;           // maximum number of strides in single trial
bool shouldStim[maxStrides] = {false}; // array of whether to stimulate for a stride
unsigned long timeTargetStimL = 198;   // initialize RTO delay to 198 ms
unsigned long timeTargetStimR = 198;   // initialize LTO delay to 198 ms
float percentSS2Stim = 0.50;           // percentage of single stance phase
float alpha = 0.7;                     // smoothing factor (0 < alpha <= 1)
// NOTE: initial estimate set based on normative data from Liu et al. 2014
// (Gait & Posture), which includes mean "normal" velocity of 1.17+/-0.14 m/s
// (N=95, 34.9+/-11.8 years), mean gait cycle duration of 1062.02 ms, and
// mean percentage of single stance of 37.34% (Table 4) giving 396.6 ms in
// single stance, 426.0 ms (slow speed) or 362.9 ms (fast). These values are
// comparable to those of Hebenstreit et al. 2015 (Human Movement Science).
// Using a better initial estimate may improve the stimulation timing
// precision of the first few strides within a trial.
float estSSL = 396.6;                  // estimated single stance duration left (initially 396.6 ms)
float estSSR = 396.6;                  // estimated single stance duration right (initially 396.6 ms)
unsigned long durSSL = 397;            // left single stance duration
unsigned long durSSR = 397;            // right single stance duration
bool canStimL = false;                 // is stimulation allowed at this time?
bool canStimR = false;                 // is stimulation allowed at this time?
// bool shouldStimL = false;              // should stimulate left leg this stride?
// bool shouldStimR = false;              // should stimulate right leg this stride?
bool shouldRunSM = false;            // should run gait event state machine?
bool isStimmingL = false;            // is the left stimulator currently on?
bool isStimmingR = false;            // is the right stimulator currently on?
unsigned long timeStimStartL = 0;    // time when left stimulation started
unsigned long timeStimStartR = 0;    // time when right stimulation started
unsigned long timeStanceChangeR = 0; // time when isCurrentStance changes
unsigned long timeStanceChangeL = 0;
unsigned long timeSinceStanceChangeL = 0;
unsigned long timeSinceStanceChangeR = 0;

// gait phase: 0 = initial double support, 1 = single L support, 2 = single R
// support, 3 = double support from single L support, 4 = double support from
// single R support
int phase = 0;
int phasePrev = 5;
int numStepsL = 0; // left step counter
int numStepsR = 0; // right step counter
int loopNum = 0;

// z-axis force threshold in DAQ bits (estimated by observing the z-axis
// force plate voltages during walking and converting to bits based on 10-bit
// ADC; we also verified that the Arduino-read bits are comparable to what we
// expect given the Vicon-read voltages, although we found a small bias)
// based on the 30 N force threshold implemented in MATLAB
// TODO: it may be necessary to increase to account for left FP noise and
// higher baud rate in Arduino than in MATLAB (more susceptible to false gait
// event detection))
const int threshFzUp = 30; // force threshold bits to detect stance phase
const int threshFzDown = 2;
const int durStimPulse = 20; // stimulation pulse duration [ms]

// right and left stimulator pin configurations
const int pinInFzR = A1;
const int pinOutStimR = 8;
const int pinOutViconR = 11;
const int pinInFzL = A0;
const int pinOutStimL = 9;
const int pinOutViconL = 12;

void setup()
{
  Serial.begin(115200);
  pinMode(pinOutStimR, OUTPUT);
  pinMode(pinOutViconR, OUTPUT);
  pinMode(pinOutStimL, OUTPUT);
  pinMode(pinOutViconL, OUTPUT);
}

void loop()
{
  // if (!shouldRunSM)
  // {
  //   processSerialCommands();
  // }
  // else
  // {
  updateGaitEventStateMachine();
  triggerStimulation();
  handleStimulationTimeout();
  // }
}

void processSerialCommands()
{
  // check for input from MATLAB
  if (Serial.available() > 0)
  {
    String command = Serial.readStringUntil('\n');
    command.trim();

    if (command == "START_SM")
    {
      // reset gait event state machine variables at start of trial
      isCurrStanceL = false;
      isCurrStanceR = false;
      isPrevStanceL = false;
      isPrevStanceR = false;
      phase = 0;
      numStepsL = 0;
      numStepsR = 0;
      shouldRunSM = true;
    }
    else if (command.startsWith("STIM"))
    {
      String data = command.substring(5);                 // Get everything after "STIM"
      for (int i = 0; i < data.length() && i < 1000; i++) // Ensure array bounds
      {
        shouldStim[i] = (data.charAt(i) == '1'); // Convert '0' or '1' to boolean
      }
    }
  }
}

void updateGaitEventStateMachine()
{
  // implement gait event state machine to update gait phase
  isPrevStanceL = isCurrStanceL;
  isPrevStanceR = isCurrStanceR;

  // read z-axis force plate sensor values to detect new stance phase
  float rightSensorVal = analogRead(pinInFzR);
  float leftSensorVal = analogRead(pinInFzL);

  // current step is stance if foot in contact with force plate
  if (isCurrStanceL)
  {
    isCurrStanceL = leftSensorVal > threshFzDown;
  }
  else
  {
    isCurrStanceL = leftSensorVal > threshFzUp;
  }

  if (isCurrStanceR)
  {
    isCurrStanceR = rightSensorVal > threshFzDown;
  }
  else
  {
    isCurrStanceR = rightSensorVal > threshFzUp;
  }

  timeSinceStanceChangeL = millis() - timeStanceChangeL;
  timeSinceStanceChangeR = millis() - timeStanceChangeR;

  // TODO: create variable for 50 ms de-bouncing constant
  if (isCurrStanceL != isPrevStanceL && timeSinceStanceChangeL > 50 && timeSinceStanceChangeR > 50)
  {
    timeStanceChangeL = millis();
    LHS = isCurrStanceL && !isPrevStanceL; // left heel strike detection
    LTO = !isCurrStanceL && isPrevStanceL; // left toe off detection
  }

  if (isCurrStanceR != isPrevStanceR && timeSinceStanceChangeR > 50 && timeSinceStanceChangeL > 50)
  {
    timeStanceChangeR = millis();
    RHS = isCurrStanceR && !isPrevStanceR; // right heel strike detection
    RTO = !isCurrStanceR && isPrevStanceR; // right toe off detection
  }

  // gait event state machine to determine phase transitions
  switch (phase)
  {
  case 0:    // initial double support phase
    if (RTO) // if right toe off, enter left single stance
    {
      phase = 1;
      numStepsR++;        // increment right step count
      timeRTO = millis(); // store time of RTO event
    }
    else if (LTO) // if left toe off, enter right single stance
    {
      phase = 2;
      numStepsL++;        // increment left step count
      timeLTO = millis(); // store time of LTO event
    }
    break;

  case 1:    // left single stance
    if (RHS) // if right heel strike, enter double stance
    {
      phase = 3;
      // TODO: consider reimplementing if beneficial
      // if (LTO) {
      //   // if missed entire phase switch due to short double stance
      //   phase = 2;
      //   numStepsL++;
      //   timeLTO = millis();
      // }
      timeRHS = millis(); // update current RHS time
      // RHS marks the end of single stance L
      // compute duration of left leg single stance phase
      durSSL = timeRHS - timeRTO;
      // estimate single stance duration using exponential updating factor
      estSSL = alpha * float(durSSL) + (1.0 - alpha) * estSSL;
      timeTargetStimL = estSSL * percentSS2Stim;
      canStimL = true; // enable stimulation
    }
    break;

  case 2:    // right single stance
    if (LHS) // if left heel strike, enter double stance
    {
      phase = 4;
      // TODO: consider reimplementing if beneficial
      // if (RTO) {
      //   // if missed entire phase switch due to short double stance
      //   phase = 1;
      //   numStepsR++;
      //   timeRTO = millis();
      // }
      timeLHS = millis(); // update current LHS time
      // LHS marks the end of single stance R
      // compute duration of right leg single stance phase
      durSSR = timeLHS - timeLTO;
      // estimate single stance duration using exponential updating factor
      estSSR = alpha * float(durSSR) + (1.0 - alpha) * estSSR;
      timeTargetStimR = estSSR * percentSS2Stim;
      canStimR = true; // enable stimulation
    }
    break;

  case 3:    // double stance after left single stance
    if (LTO) // if left toe off, enter right single stance
    {
      phase = 2;
      timeLTO = millis(); // update current LTO time
      numStepsL++;        // increment left step count
    }
    break;

  case 4:    // double stance after right single stance
    if (RTO) // if right toe off, enter left single stance
    {
      phase = 1;
      timeRTO = millis(); // update current RTO time
      numStepsR++;        // increment right step count
    }
    break;
  }
  loopNum++;
}

void triggerStimulation()
{
  unsigned long timeSinceLTO = millis() - timeLTO;
  unsigned long timeSinceRTO = millis() - timeRTO;

  // right leg stimulation trigger conditions
  // use contralateral leg (i.e., LHS - LTO) to determine R mid-single stance
  if (phase == 2 && canStimR && numStepsR % freqStim == 0 && timeSinceLTO >= timeTargetStimR && !isStimmingR)
  {
    digitalWrite(pinOutStimR, HIGH);
    digitalWrite(pinOutViconR, HIGH);
    isStimmingR = true;
    timeStimStartR = millis();
    canStimR = false;
    // shouldStimR = false; // reset trigger for next cycle
  }

  // left leg stimulation trigger conditions
  // use contralateral leg (i.e., RHS - RTO) to determine L mid-single stance
  if (phase == 1 && canStimL && numStepsL % freqStim == 0 && timeSinceRTO >= timeTargetStimL && !isStimmingL)
  {
    digitalWrite(pinOutStimL, HIGH);
    digitalWrite(pinOutViconL, HIGH);
    isStimmingL = true;
    timeStimStartL = millis();
    canStimL = false;
    // shouldStimL = false; // reset trigger for next cycle
  }
}

void handleStimulationTimeout()
{
  unsigned long now = millis();

  // right stimulation timeout
  if (isStimmingR && (now - timeStimStartR) >= durStimPulse)
  {
    digitalWrite(pinOutStimR, LOW);
    digitalWrite(pinOutViconR, LOW);
    isStimmingR = false;
  }

  // left stimulation timeout
  if (isStimmingL && (now - timeStimStartL) >= durStimPulse)
  {
    digitalWrite(pinOutStimL, LOW);
    digitalWrite(pinOutViconL, LOW);
    isStimmingL = false;
  }
}
