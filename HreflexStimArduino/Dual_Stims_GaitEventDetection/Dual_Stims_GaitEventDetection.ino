// Code to stimulate the tibial nerve of both legs for Spinal Adaptation
// study to measure H-reflexes during split-belt adaptation
// date (started): 20 Mar. 2024
// author(s): SL, NWB

/////////////////////////////////////////////////////////////////////////////
////// THE BELOW TREADMILL SPEEDS MUST BE UPDATED BEFORE EVERY TRIAL ////////
/////////////////////////////////////////////////////////////////////////////
float rightTreadmillSpeed = 0.4;  // Right treadmill belt speed [m/s]
float leftTreadmillSpeed = 0.8;   // Left treadmill belt speed [m/s]

int rightDelayTime = 200;         // Heel strike delay for right leg [ms]
int leftDelayTime = 200;          // Heel strike delay for left leg [ms]

// variables to track gait events and phases
bool new_stanceL = false;
bool new_stanceR = false;
bool old_stanceL = false;
bool old_stanceR = false;
bool LHS = false;                 // Left heel strike
bool RHS = false;                 // Right heel strike
bool LTO = false;                 // Left toe off
bool RTO = false;                 // Right toe off
bool canStim = false;             // Flag to enable stimulation
// Gait phase: 0 = double support, 1 = single L support, 2 = single R support
int phase = 0;
int LstepCount = 0;               // Left step counter
int RstepCount = 0;               // Right step counter

const int threshFz = 5;           // Force thresh. [N] to detect stance phase
const int numStrides = 10;        // Number of steps after which to stimulate

// right and left stimulator pin configurations
const int rightSensorPin = A1;
const int rightOutputPin = 8;
const int rightViconOut = 11;
const int leftSensorPin = A0;
const int leftOutputPin = 9;
const int leftViconOut = 12;

void setup() {
  Serial.begin(9600);
  rightDelayTime = (-73.8 * rightTreadmillSpeed) + 384.4; // Right delay calc
  leftDelayTime = (-73.8 * leftTreadmillSpeed) + 384.4;   // Left delay calc
  Serial.println("\n\n\n\nSTART");
}

void loop() {
  old_stanceL = new_stanceL;
  old_stanceR = new_stanceR;

  // read sensor values to detect new stance phase
  float rightSensorVal = analogRead(rightSensorPin);
  float leftSensorVal = analogRead(leftSensorPin);

  new_stanceL = leftSensorVal > threshFz;   // detect left stance
  new_stanceR = rightSensorVal > threshFz;  // detect right stance

  LHS = new_stanceL && !old_stanceL;        // Left heel strike detection
  RHS = new_stanceR && !old_stanceR;        // Right heel strike detection
  LTO = !new_stanceL && old_stanceL;        // Left toe off detection
  RTO = !new_stanceR && old_stanceR;        // Right toe off detection

  // gait state machine to determine phase transitions
  switch (phase) {
    case 0:  // Initial double support phase
      if (RTO) {           // If right toe off, enter left single stance
        phase = 1;
        RstepCount++;      // Increment right step count
        Serial.print("Right Step: ");
        Serial.println(RstepCount);
      } else if (LTO) {    // If left toe off, enter right single stance
        phase = 2;
        LstepCount++;      // Increment left step count
        Serial.print("Left Step: ");
        Serial.println(LstepCount);
      }
      break;

    case 1:  // Left single stance
      if (RHS) {           // If right heel strike, enter double stance
        phase = 3;
        // if (LTO) {
        //   // if missed entire phase switch due to short double stance
        //   phase = 2;
        //   LstepCount++;
        // }
        canStim = true;    // Enable stimulation
      }
      break;

    case 2:  // Right single stance
      if (LHS) {           // If left heel strike, enter double stance
        phase = 4;
        // if (RTO) {
        //   // if missed entire phase switch due to short double stance
        //   phase = 1;
        //   RstepCount++;
        // }
        canStim = true;    // Enable stimulation
      }
      break;

    case 3:  // Double stance following left single stance
      if (LTO) {           // If left toe off, enter right single stance
        phase = 2;
        LstepCount++;      // Increment left step count
        Serial.print("Left Step: ");
        Serial.println(LstepCount);
      }
      break;

    case 4:  // Double stance following right single stance
      if (RTO) {           // If right toe off, enter left single stance
        phase = 1;
        RstepCount++;      // Increment right step count
        Serial.print("Right Step: ");
        Serial.println(RstepCount);
      }
      break;
  }

  // Right leg stimulation condition
  if ((!(RstepCount % numStrides)) && phase == 2 && canStim) {
    Serial.println("Right Stimulation Triggered");
    delay(rightDelayTime);
    digitalWrite(rightOutputPin, HIGH);
    digitalWrite(rightViconOut, HIGH);
    delay(20);  // Stimulation duration
    digitalWrite(rightOutputPin, LOW);
    digitalWrite(rightViconOut, LOW);
    canStim = false;
  }

  // Left leg stimulation condition
  if ((!(LstepCount % numStrides)) && phase == 1 && canStim) {
    Serial.println("Left Stimulation Triggered");
    delay(leftDelayTime);
    digitalWrite(leftOutputPin, HIGH);
    digitalWrite(leftViconOut, HIGH);
    delay(20);  // Stimulation duration
    digitalWrite(leftOutputPin, LOW);
    digitalWrite(leftViconOut, LOW);
    canStim = false;
  }
}

