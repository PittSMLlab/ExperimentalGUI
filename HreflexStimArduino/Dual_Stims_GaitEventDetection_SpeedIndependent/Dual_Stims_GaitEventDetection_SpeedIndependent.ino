// Updated code to stimulate the tibial nerve of both legs for the Spinal
// Adaptation study to measure H-reflexes during split-belt adaptation. This
// version of the code has been further updated to include the gait event
// detection state machine and to remove speed dependence (i.e., the need to
// manually update the treadmill speeds before each trial) by storing the
// single stance duration of the previous two strides.
// date (started): 26 Mar. 2024
// author(s): SL, NWB

// initialize variables
bool new_stanceL = false;             // is current step left foot stance?
bool new_stanceR = false;             // is current step right foot stance?
bool old_stanceL = false;             // is previous step left foot stance?
bool old_stanceR = false;             // is previous step right foot stance?
bool LHS = false;                     // is there a left heel strike event?
bool RHS = false;                     // is there a right heel strike event?
bool LTO = false;                     // is there a left toe off event?
bool RTO = false;                     // is there a right toe off event?
unsigned long timeLHS = 0;            // time of most recent LHS events
unsigned long timeRHS = 0;            // time of most recent RHS events
unsigned long timeLTO = 0;            // time of most recent LTO events
unsigned long timeRTO = 0;            // time of most recent RTO events
unsigned long timeSinceLTO = 0;       // time since most recent LTO event
unsigned long timeSinceRTO = 0;       // time since most recent RTO event
unsigned long stimDelayL = 100;       // initialize RTO delay to 100 ms
unsigned long stimDelayR = 100;       // initialize LTO delay to 100 ms
unsigned long durSSL[2] = { 0, 0 };   // two left single stance durations
unsigned long durSSR[2] = { 0, 0 };   // two right single stance durations
bool canStim = false;                 // is stimulation allowed at this time?
// gait phase state machine: 0 = initial double support, 1 = single stance L,
// 2 = single stance R, 3 = double stance from single stance L, 4 = double
// stance from single R
int phase = 0;
int LstepCount = 0;                   // left leg step counter
int RstepCount = 0;                   // right leg step counter
// z-axis force threshold in DAQ bits (estimated by observing the z-axis
// force plate voltages during walking and converting to bits based on 10-bit
// ADC; we also verified that the Arduino-read bits are comparable to what we
// expect given the Vicon-read voltages, although we found a small bias)
// based on the 30 N force threshold implemented in MATLAb
// TODO: it may be necessary to increase to account for left FP noise and
// higher baud rate in Arduino than in MATLAB (more susceptible to false gait
// event detection))
int threshFz = 5;
int numStrides = 10;  // number of strides after which to stimulate both legs

// right stimulator configuration
const int rightSensorPin = A1;
const int rightOutputPin = 8;
const int rightViconOut = 11;

// left stimulator configuration
const int leftSensorPin = A0;
const int leftOutputPin = 9;
const int leftViconOut = 12;

void setup() {
  Serial.begin(600);  // TODO: consider increasing to higher baud rate
  Serial.println("\n\n\n\nSTART");
}

void loop() {                   // main loop function
  old_stanceL = new_stanceL;    // update previous step stance boolean
  old_stanceR = new_stanceR;

  // Read z-axis force plate values from the sensor pins
  float rightSensorVal = analogRead(rightSensorPin);
  float leftSensorVal = analogRead(leftSensorPin);

  // current step is stance if foot in contact with force plate
  new_stanceL = leftSensorVal > threshFz;
  new_stanceR = rightSensorVal > threshFz;

  LHS = new_stanceL && (!old_stanceL);
  RHS = new_stanceR && (!old_stanceR);
  LTO = (!new_stanceL) && old_stanceL;
  RTO = (!new_stanceR) && old_stanceR;

  // state machine: 0 = initial, 1 = single stance L, 2 = single stance R,
  // 3 = double stance from single stance L, 4 = double stance from single R
  switch (phase) {              // process based on current gait phase
    case 0:                     // double stance, only the initial phase
      if (RTO) {                // if there is a R toe off event, ...
        phase = 1;              // progress to single stance L
        RstepCount++;           // increment right step count
        timeRTO = millis();     // store time of RTO event
        Serial.print("1st R: ");
        Serial.println(RstepCount);
      } else if (LTO) {         // if there is a L toe off event, ...
        phase = 2;              // progress to single stance R
        LstepCount++;           // increment left step count
        timeRTO = millis();     // store time of LTO event
        Serial.print("1st LLLLL: ");
        Serial.println(LstepCount);
      }
      break;
    case 1:                     // single stance L
      if (RHS) {                // if there is a R heel strike event, ...
        phase = 3;              // progress to double stance
        // TODO: consider reimplementing if beneficial
        // if (LTO) {
        //   // in case double stance is too short and a full cycle misses the
        //   // phase switch
        //   phase = 2;
        //   LstepCount++;
        // }
        timeRHS = millis();     // update current RHS time
        // RHS marks the end of single stance L
        durSSL[0] = durSSL[1];  // overwrite previous SSL duration
        // compute duration of left leg single stance phase
        durSSL[1] = timeRHS - timeRTO;
        // delay of left leg stimulation from RTO is mean of single stance
        // duration divided by two (since targeting mid-point of single
        // stance for stimulus pulse)
        // TODO: consider weighting most recent SSL duration more heavily
        // (e.g., 75% since likely more predictive)
        stimDelayL = ((durSSL[0] / 3) + (2*durSSL[1] / 3)) / 2;
        Serial.print("This is L Delay: ");
        Serial.println(stimDelayL);
        Serial.println();
        canStim = true;         // enable stimulation
      }
      break;
    case 2:                     // single stance R
      if (LHS) {                // if there is a L heel strike event, ...
        phase = 4;              // progress to double stance
        // TODO: consider reimplementing if beneficial
        // if (RTO) {
        //   // in case double stance is too short and a full cycle misses the
        //   // phase switch
        //   phase = 1;
        //   RstepCount++;
        // }
        timeLHS = millis();     // update current LHS time
        // LHS marks the end of single stance R
        durSSR[0] = durSSR[1];  // overwrite previous SSR duration
        // compute duration of right leg single stance phase
        durSSR[1] = timeLHS - timeLTO;
        // delay of right leg stimulation from LTO is mean of single stance
        // duration divided by two (since targeting mid-point of single
        // stance for stimulus pulse)
        stimDelayR = ((durSSR[0] / 3) + (2*durSSR[1] / 3)) / 2;
        Serial.print("This is R Delay: ");
        Serial.println(stimDelayR);
        Serial.println();
        canStim = true;         // enable stimulation
      }
      break;
    case 3:                     // double stance, coming from single stance L
      if (LTO) {                // if there is a L toe off event, ...
        phase = 2;              // progress to single stance R
        timeLTO = millis();     // update current LTO time
        LstepCount++;           // increment the step counter
        Serial.print("LLLLLL: ");
        Serial.println(LstepCount);
      }
      break;
    case 4:                     // double stance, coming from single stance R
      if (RTO) {                // if there is a R toe off event, ...
        phase = 1;              // progress to single stance L
        timeRTO = millis();     // update current RTO time
        RstepCount++;           // increment the step counter
        Serial.print("R: ");
        Serial.println(RstepCount);
      }
      break;
    default:
      // it is never possible to enter the default case
      break;
  }

  timeSinceLTO = millis() - timeLTO;
  // use contralateral leg (i.e., LHS - LTO) to determine R mid-single stance
  if ((!((RstepCount-2) % numStrides)) && phase == 2 && canStim && (timeSinceLTO >= stimDelayR)) {
    digitalWrite(rightOutputPin, HIGH);
    digitalWrite(rightViconOut, HIGH);
    // TODO: consider removing delay here too to allow state machine to continue running for these 20 ms
    delay(20);
    digitalWrite(rightOutputPin, LOW);
    digitalWrite(rightViconOut, LOW);
    canStim = false;
  }

  // TODO: consider using ONLY RstepCount to force stimulation order of right left within one stride
  timeSinceRTO = millis() - timeRTO;
  // use contralateral leg (i.e., RHS - RTO) to determine L mid-single stance
  if ((!((RstepCount-2) % numStrides)) && phase == 1 && canStim && (timeSinceRTO >= stimDelayL)) {
    digitalWrite(leftOutputPin, HIGH);
    digitalWrite(leftViconOut, HIGH);
    // TODO: consider removing delay here too to allow state machine to continue running for these 20 ms
    delay(20);
    digitalWrite(leftOutputPin, LOW);
    digitalWrite(leftViconOut, LOW);
    canStim = false;
  }
}

