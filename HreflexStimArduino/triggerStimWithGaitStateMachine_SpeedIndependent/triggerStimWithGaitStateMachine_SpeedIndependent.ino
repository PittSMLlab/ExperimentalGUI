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
bool isCurrStanceL = false;          // is current step left foot stance?
bool isCurrStanceR = false;          // is current step right foot stance?
bool isPrevStanceL = false;          // is previous step left foot stance?
bool isPrevStanceR = false;          // is previous step right foot stance?
bool LHS = false;                    // is there a left heel strike event?
bool RHS = false;                    // is there a right heel strike event?
bool LTO = false;                    // is there a left toe off event?
bool RTO = false;                    // is there a right toe off event?
unsigned long timeLHS = 0;           // time of most recent LHS events
unsigned long timeRHS = 0;           // time of most recent RHS events
unsigned long timeLTO = 0;           // time of most recent LTO events
unsigned long timeRTO = 0;           // time of most recent RTO events
unsigned long timeTargetStimL = 100; // initialize RTO delay to 100 ms
unsigned long timeTargetStimR = 100; // initialize LTO delay to 100 ms
float percentSS2Stim = 0.65;         // Percentage of single stance phase
float alpha = 0.7;                   // smoothing factor (0 < alpha <= 1)
float estSSL = 0.0;                  // estimated single stance duration left
float estSSR = 0.0;                  // estimated single stance duration right
unsigned long durSSL = 0;            // two left single stance durations
unsigned long durSSR = 0;            // two right single stance durations
bool canStim = false;                // is stimulation allowed at this time?
bool shouldStimL = false;            // should stimulate left leg this stride?
bool shouldStimR = false;            // should stimulate right leg this stride?
bool shouldRunSM = false;            // should run gait event state machine?
bool isStimmingL = false;            // is the left stimulator currently on?
bool isStimmingR = false;            // is the right stimulator currently on?
unsigned long timeStimStartL = 0;    // time when left stimulation started
unsigned long timeStimStartR = 0;    // time when right stimulation started

// gait phase: 0 = initial double support, 1 = single L support, 2 = single R
// support, 3 = double support from single L support, 4 = double support from
// single R support
int phase = 0;
int numStepsL = 0; // left step counter
int numStepsR = 0; // right step counter

// z-axis force threshold in DAQ bits (estimated by observing the z-axis
// force plate voltages during walking and converting to bits based on 10-bit
// ADC; we also verified that the Arduino-read bits are comparable to what we
// expect given the Vicon-read voltages, although we found a small bias)
// based on the 30 N force threshold implemented in MATLAB
// TODO: it may be necessary to increase to account for left FP noise and
// higher baud rate in Arduino than in MATLAB (more susceptible to false gait
// event detection))
const int threshFz = 5;      // force threshold bits to detect stance phase
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
  Serial.begin(9600);
  Serial.println("START");
  pinMode(pinOutStimR, OUTPUT);
  pinMode(pinOutViconR, OUTPUT);
  pinMode(pinOutStimL, OUTPUT);
  pinMode(pinOutViconL, OUTPUT);
}

void loop()
{
  processSerialCommands();
  if (shouldRunSM)
  {
    updateGaitEventStateMachine();
    triggerStimulation();
  }
  handleStimulationTimeout();
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
      numStepsL = 0;
      numStepsR = 0;
      shouldRunSM = true;
      Serial.println("Reset step counters, and started state machine.");
    }
    else if (command == "STOP_SM")
    {
      shouldRunSM = false;
      Serial.println("Stopped state machine.");
    }
    else if (command == "STIM_RIGHT")
    {
      shouldStimR = true;
      Serial.println("Right leg stimulation enabled.");
    }
    else if (command == "STIM_LEFT")
    {
      shouldStimL = true;
      Serial.println("Left leg stimulation enabled.");
    }
    else
    {
      Serial.println("Unknown command received.");
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
  isCurrStanceL = leftSensorVal > threshFz;  // detect left stance
  isCurrStanceR = rightSensorVal > threshFz; // detect right stance
  LHS = isCurrStanceL && !isPrevStanceL;     // left heel strike detection
  RHS = isCurrStanceR && !isPrevStanceR;     // right heel strike detection
  LTO = !isCurrStanceL && isPrevStanceL;     // left toe off detection
  RTO = !isCurrStanceR && isPrevStanceR;     // right toe off detection

  // gait event state machine to determine phase transitions
  switch (phase)
  {
  case 0:    // initial double support phase
    if (RTO) // if right toe off, enter left single stance
    {
      phase = 1;
      numStepsR++;        // increment right step count
      timeRTO = millis(); // store time of RTO event
      Serial.print("Right Step: ");
      Serial.println(numStepsR);
    }
    else if (LTO) // if left toe off, enter right single stance
    {
      phase = 2;
      numStepsL++;        // increment left step count
      timeLTO = millis(); // store time of LTO event
      Serial.print("Left Step: ");
      Serial.println(numStepsL);
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
      canStim = true; // enable stimulation
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
      canStim = true; // enable stimulation
    }
    break;

  case 3:    // double stance after left single stance
    if (LTO) // if left toe off, enter right single stance
    {
      phase = 2;
      timeLTO = millis(); // update current LTO time
      numStepsL++;        // increment left step count
      Serial.print("Left Step: ");
      Serial.println(numStepsL);
    }
    break;

  case 4:    // double stance after right single stance
    if (RTO) // if right toe off, enter left single stance
    {
      phase = 1;
      timeRTO = millis(); // update current RTO time
      numStepsR++;        // increment right step count
      Serial.print("Right Step: ");
      Serial.println(numStepsR);
    }
    break;
  }
}

void triggerStimulation()
{
  unsigned long timeSinceLTO = millis() - timeLTO;
  unsigned long timeSinceRTO = millis() - timeRTO;

  // right leg stimulation trigger conditions
  // use contralateral leg (i.e., LHS - LTO) to determine R mid-single stance
  if (phase == 2 && canStim && shouldStimR && timeSinceLTO >= timeTargetStimR && !isStimmingR)
  {
    Serial.println("Right Stimulation Triggered");
    digitalWrite(pinOutStimR, HIGH);
    digitalWrite(pinOutViconR, HIGH);
    isStimmingR = true;
    timeStimStartR = millis();
    canStim = false;
    shouldStimR = false; // reset trigger for next cycle
  }

  // left leg stimulation trigger conditions
  // use contralateral leg (i.e., RHS - RTO) to determine L mid-single stance
  if (phase == 1 && canStim && shouldStimL && timeSinceRTO >= timeTargetStimL && !isStimmingL)
  {
    Serial.println("Left Stimulation Triggered");
    digitalWrite(pinOutStimL, HIGH);
    digitalWrite(pinOutViconL, HIGH);
    isStimmingL = true;
    timeStimStartL = millis();
    canStim = false;
    shouldStimL = false; // reset trigger for next cycle
  }
}

void handleStimulationTimeout()
{
  if (isStimmingR && millis() - timeStimStartR >= durStimPulse)
  {
    digitalWrite(pinOutStimR, LOW);
    digitalWrite(pinOutViconR, LOW);
    isStimmingR = false;
    Serial.println("Right Stimulation Ended");
  }

  if (isStimmingL && millis() - timeStimStartL >= durStimPulse)
  {
    digitalWrite(pinOutStimL, LOW);
    digitalWrite(pinOutViconL, LOW);
    isStimmingL = false;
    Serial.println("Left Stimulation Ended");
  }
}
