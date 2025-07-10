// Code to stimulate the tibial nerve of both legs for the Spinal Adaptation
// study to measure H-reflexes during split-belt adaptation. Updated to
// accept Serial input from MATLAB to indicate whether to stimulate on the
// current stride. Includes the gait event detection state machine and
// removes speed dependence by storing a continuously updated single stance
// duration estimate. A median filter is applied to the analog force signal
// to reduce noise.
// date (started): 26 Mar. 2024
// author(s): SL, NWB

// -------------------------- Pin Definitions --------------------------
const int pinInFzL = A0;     // left force plate sensor input
const int pinOutStimL = 9;   // left stimulation output
const int pinOutViconL = 12; // left Vicon output
const int pinInFzR = A1;     // right force plate sensor input
const int pinOutStimR = 8;   // right stimulation output
const int pinOutViconR = 11; // right Vicon output

// -------------------------- Constants & Parameters --------------------------
// z-axis force threshold in DAQ bits (estimated by observing the z-axis
// force plate voltages during walking and converting to bits based on 10-bit
// ADC; we also verified that the Arduino-read bits are comparable to what we
// expect given the Vicon-read voltages, although we found a small bias)
// TODO: it may be necessary to increase to account for left FP noise and
// higher baud rate in Arduino than in MATLAB (more susceptible to false gait
// event detection))
const int threshFzUp = 30;              // force threshold (bits) for detecting stance (upper)
const int threshFzDown = 2;             // force threshold for detecting stance (lower)
const int durStimPulse = 20;            // stimulation pulse duration (ms)
const unsigned long timeDebounce = 100; // de-bouncing time constant (ms)
const float percentSS2Stim = 0.50;      // 50% of single stance phase target
const float alpha = 0.7;                // smoothing factor (0 < alpha <= 1)
const float alphaLPF = 0.02;            // low-pass filter smoothing (0 < alpha << 1)
const unsigned long intervalLog = 5;    // ms between CSV logs
unsigned long timeLastLog = 0;

// -------------------------- Global Variables --------------------------
// gait event state variables
bool isCurrStanceL = false; // is current step left foot stance?
bool isCurrStanceR = false; // is current step right foot stance?
bool isPrevStanceL = false; // is previous step left foot stance?
bool isPrevStanceR = false; // is previous step right foot stance?
bool LHS = false;           // is there a left heel strike event?
bool RHS = false;           // is there a right heel strike event?
bool LTO = false;           // is there a left toe off event?
bool RTO = false;           // is there a right toe off event?

// continuous filtered forces
float filtL = 0;
float filtR = 0;

// timing variables (in ms)
unsigned long timeLHS = 0;           // time of most recent LHS events
unsigned long timeRHS = 0;           // time of most recent RHS events
unsigned long timeLTO = 0;           // time of most recent LTO events
unsigned long timeRTO = 0;           // time of most recent RTO events
unsigned long timeSinceLTO = 0;      // time since LTO event
unsigned long timeSinceRTO = 0;      // time since RTO event
unsigned long timeStanceChangeL = 0; // time when isCurrentStance changes
unsigned long timeStanceChangeR = 0;
unsigned long timeSinceStanceChangeL = 0; // time elapsed since isCurrentStance changed
unsigned long timeSinceStanceChangeR = 0;
unsigned long timeTargetStimL = 198; // initial RTO delay estimate for left stimulation
unsigned long timeTargetStimR = 198; // initial LTO delay estimate for right stimulation

// single stance duration estimates & measured durations
// NOTE: initial estimate set based on normative data from Liu et al. 2014
// (Gait & Posture), which includes mean "normal" velocity of 1.17+/-0.14 m/s
// (N=95, 34.9+/-11.8 years), mean gait cycle duration of 1062.02 ms, and
// mean percentage of single stance of 37.34% (Table 4) giving 396.6 ms in
// single stance, 426.0 ms (slow speed) or 362.9 ms (fast). These values are
// comparable to those of Hebenstreit et al. 2015 (Human Movement Science).
// Using a better initial estimate may improve the stimulation timing
// precision of the first few strides within a trial.
float estSSL = 396.6; // estimated single stance duration (ms)
float estSSR = 396.6;
unsigned long durSSL = 397; // measured single stance duration (ms)
unsigned long durSSR = 397;

// stimulation control flags
// int freqStim = 1;                 // temporary stride frequency of stimulation for development
// bool canStimL = false;            // is stimulation allowed at this time?
// bool canStimR = false;            // is stimulation allowed at this time?
bool shouldStimL = false;         // should stimulate left leg this stride?
bool shouldStimR = false;         // should stimulate right leg this stride?
bool shouldRunSM = false;         // should run gait event state machine?
bool isStimmingL = false;         // is the left stimulator currently on?
bool isStimmingR = false;         // is the right stimulator currently on?
unsigned long timeStimStartL = 0; // time when left stimulation started
unsigned long timeStimStartR = 0; // time when right stimulation started

// gait phase & step counts
// gait phase: 0 = initial double support, 1 = single L support, 2 = single R
// support, 3 = double support from single L support, 4 = double support from
// single R support
int phase = 0;
int numStepsL = 0; // left step counter
int numStepsR = 0; // right step counter

// serial communication variable
int command = 0;

// -------------------------- Setup --------------------------
void setup()
{
  Serial.begin(115200);
  // ensure pins are properly set for output
  pinMode(pinOutStimL, OUTPUT);
  pinMode(pinOutViconL, OUTPUT);
  pinMode(pinOutStimR, OUTPUT);
  pinMode(pinOutViconR, OUTPUT);
}

// -------------------------- Main Loop --------------------------
void loop()
{
  processSerialCommands();
  if (shouldRunSM) // if should run the gait event state machine, ...
  {
    updateGaitEventStateMachine();
    triggerStimulation();
  }
  handleStimulationTimeout();
  // logForceCSV();
}

// -------------------------- Serial Communication --------------------------
void processSerialCommands()
{
  // check for input from MATLAB
  if (Serial.available())
  {
    command = Serial.read();
    switch (command)
    {
    case 0: // start gait event state machine
      // reset gait event state machine variables at start of trial
      resetStateMachine();
      break;

    case 1: // stimulate the left leg
      shouldStimL = true;
      break;

    case 2: // stimulate the right leg
      shouldStimR = true;
      break;

    case 3: // stop gait event state machine
      shouldRunSM = false;
      break;

    default:
      // unrecognized command; do nothing
      break;
    }
  }
}

void resetStateMachine()
{
  isCurrStanceL = false;
  isCurrStanceR = false;
  isPrevStanceL = false;
  isPrevStanceR = false;
  phase = 0;
  numStepsL = 0;
  numStepsR = 0;
  shouldRunSM = true;
}

// -------------------------- Median Filter Function --------------------------
// This function takes 'numSamples' analog readings from the specified pin,
// sorts them, and returns the median value.
int medianFilter(int pin, int numSamples = 9)
{
  int samples[9];                           // use an odd number for a simple median
  numSamples = constrain(numSamples, 1, 9); // prevent overflow
  for (int i = 0; i < numSamples; i++)
  {
    samples[i] = analogRead(pin);
    delayMicroseconds(500); // short delay to get distinct samples (2kHz)
  }
  // simple bubble sort
  for (int i = 0; i < numSamples - 1; i++)
  {
    for (int j = i + 1; j < numSamples; j++)
    {
      if (samples[j] < samples[i])
      {
        int temp = samples[i];
        samples[i] = samples[j];
        samples[j] = temp;
      }
    }
  }
  return samples[numSamples / 2]; // return the median value
}

// -------------------------- Gait Event State Machine --------------------------
void updateGaitEventStateMachine()
{
  // implement gait event state machine to update gait phase
  isPrevStanceL = isCurrStanceL; // save previous stance values
  isPrevStanceR = isCurrStanceR;

  // read z-axis force plate sensor values to detect new stance phase
  // TODO: consider updating a force data buffer rather than current approach
  // use median filter for force readings to reduce noise
  int leftForce = analogRead(pinInFzL);
  int rightForce = analogRead(pinInFzR);
  // logForceData(leftForce, rightForce);

  // IIR low-pass filter
  filtL += alphaLPF * (leftForce - filtL);
  filtR += alphaLPF * (rightForce - filtR);

  // current step is stance if foot in contact with force plate
  if (isCurrStanceL)
  {
    isCurrStanceL = leftForce > threshFzDown;
  }
  else
  {
    isCurrStanceL = leftForce > threshFzUp;
  }
  if (isCurrStanceR)
  {
    isCurrStanceR = rightForce > threshFzDown;
  }
  else
  {
    isCurrStanceR = rightForce > threshFzUp;
  }

  timeSinceStanceChangeL = millis() - timeStanceChangeL;
  timeSinceStanceChangeR = millis() - timeStanceChangeR;

  // update events if stance state changes and debounce time has passed
  if (isCurrStanceL != isPrevStanceL && timeSinceStanceChangeL > timeDebounce && timeSinceStanceChangeR > timeDebounce)
  {
    timeStanceChangeL = millis();
    LHS = isCurrStanceL && !isPrevStanceL; // left heel strike detection
    LTO = !isCurrStanceL && isPrevStanceL; // left toe off detection
  }
  if (isCurrStanceR != isPrevStanceR && timeSinceStanceChangeR > timeDebounce && timeSinceStanceChangeL > timeDebounce)
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
      // canStimL = true; // enable stimulation
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
      // canStimR = true; // enable stimulation
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
}

// -------------------------- Stimulation Triggering --------------------------
void triggerStimulation()
{
  // TODO: move definition up to top
  unsigned long timeNow = millis();

  // left leg stimulation trigger conditions
  // use contralateral leg (i.e., RHS - RTO) to determine L mid-single stance
  // Use following conditions if troubleshooting:
  //  canStimL
  //  numStepsL % freqStim == 0
  if (phase == 1 && shouldStimL && !isStimmingL)
  {
    timeTargetStimL = (unsigned long)(percentSS2Stim * estSSL);

    if ((timeNow - timeRTO) >= timeTargetStimL)
    {
      digitalWrite(pinOutStimL, HIGH);
      digitalWrite(pinOutViconL, HIGH);
      timeStimStartL = millis(); // TODO: use 'timeNow' if temporally precise enough
      isStimmingL = true;
      // canStimL = false;
      shouldStimL = false; // reset trigger for next cycle
    }
  }

  // right leg stimulation trigger conditions
  // use contralateral leg (i.e., LHS - LTO) to determine R mid-single stance
  // Use following conditions if troubleshooting:
  //  canStimR
  //  numStepsR % freqStim == 0
  if (phase == 2 && shouldStimR && !isStimmingR)
  {
    timeTargetStimR = (unsigned long)(percentSS2Stim * estSSR);

    if ((timeNow - timeLTO) >= timeTargetStimR)
    {
      digitalWrite(pinOutStimR, HIGH);
      digitalWrite(pinOutViconR, HIGH);
      timeStimStartR = millis();
      isStimmingR = true;
      // canStimR = false;
      shouldStimR = false; // reset trigger for next cycle
    }
  }
}

// -------------------------- Stimulation Timeout --------------------------
void handleStimulationTimeout()
{
  unsigned long timeNow = millis();

  // left stimulation timeout
  if (isStimmingL && (timeNow - timeStimStartL) >= durStimPulse)
  {
    digitalWrite(pinOutStimL, LOW);
    digitalWrite(pinOutViconL, LOW);
    isStimmingL = false;
  }

  // right stimulation timeout
  if (isStimmingR && (timeNow - timeStimStartR) >= durStimPulse)
  {
    digitalWrite(pinOutStimR, LOW);
    digitalWrite(pinOutViconR, LOW);
    isStimmingR = false;
  }
}

// --- CSV logging of raw & filtered forces --------------
// void logForceData(int leftForce, int rightForce)
// {
//   unsigned long currentTime = millis();
//   if (currentTime - timeLastLog >= intervalLog)
//   {
//     Serial.print(currentTime);
//     Serial.print(",");
//     Serial.print(leftForce);
//     Serial.print(",");
//     Serial.println(rightForce);
//     timeLastLog = currentTime;
//   }
// }
