// Code to stimulate the tibial nerve of both legs for the Spinal Adaptation
// study to measure H-reflexes during split-belt adaptation
// date (started): 20 Mar. 2024
// author(s): SL, NWB

/////////////////////////////////////////////////////////////////////////////
////// THE BELOW TREADMILL SPEEDS MUST BE UPDATED BEFORE EVERY TRIAL ////////
/////////////////////////////////////////////////////////////////////////////
float rightTreadmillSpeed = 0.4; // Right treadmill belt speed [m/s]
float leftTreadmillSpeed = 0.8;  // Left treadmill belt speed [m/s]

int rightDelayTime = 200; // Heel strike delay for right leg [ms]
int leftDelayTime = 200;  // Heel strike delay for left leg [ms]

// initialize variables to track gait events and phases
bool new_stanceL = false; // is current step left foot stance?
bool new_stanceR = false; // is current step right foot stance?
bool old_stanceL = false; // is previous step left foot stance?
bool old_stanceR = false; // is previous step right foot stance?
bool LHS = false;         // is there a left heel strike event?
bool RHS = false;         // is there a right heel strike event?
bool LTO = false;         // is there a left toe off event?
bool RTO = false;         // is there a right toe off event?
bool canStim = false;     // is stimulation allowed at this time?
// gait phase: 0 = initial double support, 1 = single L support, 2 = single R
// support, 3 = double support from single L support, 4 = double support from
// single R support
int phase = 0;
int LstepCount = 0; // left step counter
int RstepCount = 0; // right step counter

const int threshFz = 5;           // force thresh. [N] to detect stance phase
const int numStrides = 10;        // number of strides after which to stimulate
const int stimPulseDuration = 20; // stimulation pulse duration [ms]

// right and left stimulator pin configurations
const int rightSensorPin = A1;
const int rightOutputPin = 8;
const int rightViconOut = 11;
const int leftSensorPin = A0;
const int leftOutputPin = 9;
const int leftViconOut = 12;

void setup()
{
  Serial.begin(9600);
  rightDelayTime = (-73.8 * rightTreadmillSpeed) + 384.4; // Right delay calc
  leftDelayTime = (-73.8 * leftTreadmillSpeed) + 384.4;   // Left delay calc
  Serial.println("\n\n\n\nSTART");
}

void loop()
{
  old_stanceL = new_stanceL;
  old_stanceR = new_stanceR;

  // read z-axis force plate sensor values to detect new stance phase
  float rightSensorVal = analogRead(rightSensorPin);
  float leftSensorVal = analogRead(leftSensorPin);

  // current step is stance if foot in contact with force plate
  new_stanceL = leftSensorVal > threshFz;  // detect left stance
  new_stanceR = rightSensorVal > threshFz; // detect right stance

  LHS = new_stanceL && !old_stanceL; // left heel strike detection
  RHS = new_stanceR && !old_stanceR; // right heel strike detection
  LTO = !new_stanceL && old_stanceL; // left toe off detection
  RTO = !new_stanceR && old_stanceR; // right toe off detection

  // gait event state machine to determine phase transitions
  switch (phase)
  {
  case 0: // initial double support phase
    if (RTO)
    { // if right toe off, enter left single stance
      phase = 1;
      RstepCount++; // increment right step count
      Serial.print("Right Step: ");
      Serial.println(RstepCount);
    }
    else if (LTO)
    { // if left toe off, enter right single stance
      phase = 2;
      LstepCount++; // increment left step count
      Serial.print("Left Step: ");
      Serial.println(LstepCount);
    }
    break;

  case 1: // left single stance
    if (RHS)
    { // if right heel strike, enter double stance
      phase = 3;
      // TODO: consider reimplementing if beneficial
      // if (LTO) {
      //   // if missed entire phase switch due to short double stance
      //   phase = 2;
      //   LstepCount++;
      // }
      canStim = true; // enable stimulation
    }
    break;

  case 2: // right single stance
    if (LHS)
    { // if left heel strike, enter double stance
      phase = 4;
      // TODO: consider reimplementing if beneficial
      // if (RTO) {
      //   // if missed entire phase switch due to short double stance
      //   phase = 1;
      //   RstepCount++;
      // }
      canStim = true; // enable stimulation
    }
    break;

  case 3: // double stance after left single stance
    if (LTO)
    { // if left toe off, enter right single stance
      phase = 2;
      LstepCount++; // increment left step count
      Serial.print("Left Step: ");
      Serial.println(LstepCount);
    }
    break;

  case 4: // double stance after right single stance
    if (RTO)
    { // if right toe off, enter left single stance
      phase = 1;
      RstepCount++; // increment right step count
      Serial.print("Right Step: ");
      Serial.println(RstepCount);
    }
    break;
  }

  // right leg stimulation condition
  if ((!(RstepCount % numStrides)) && phase == 2 && canStim)
  {
    Serial.println("Right Stimulation Triggered");
    delay(rightDelayTime);
    digitalWrite(rightOutputPin, HIGH);
    digitalWrite(rightViconOut, HIGH);
    // TODO: consider removing delay here too to allow state machine to
    // continue running for these 20 ms
    delay(stimPulseDuration); // stimulation duration
    digitalWrite(rightOutputPin, LOW);
    digitalWrite(rightViconOut, LOW);
    canStim = false;
  }

  // left leg stimulation condition
  if ((!(LstepCount % numStrides)) && phase == 1 && canStim)
  {
    Serial.println("Left Stimulation Triggered");
    delay(leftDelayTime);
    digitalWrite(leftOutputPin, HIGH);
    digitalWrite(leftViconOut, HIGH);
    // TODO: consider removing delay here too to allow state machine to
    // continue running for these 20 ms
    delay(stimPulseDuration); // stimulation duration
    digitalWrite(leftOutputPin, LOW);
    digitalWrite(leftViconOut, LOW);
    canStim = false;
  }
}
