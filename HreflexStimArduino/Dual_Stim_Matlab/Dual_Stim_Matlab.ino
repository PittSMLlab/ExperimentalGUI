// Updated code to stimulate the tibial nerve of both legs for the Spinal
// Adaptation study to measure H-reflexes during split-belt adaptation
// date (started): 20 Mar. 2024
// author(s): SL, NWB

/////////////////////////////////////////////////////////////////////////////
////// THE BELOW TREADMILL SPEEDS MUST BE UPDATED BEFORE EVERY TRIAL ////////
/////////////////////////////////////////////////////////////////////////////
float rightTreadmillSpeed = 0.4; // Right treadmill belt speed [m/s]
float leftTreadmillSpeed = 0.8;  // Left treadmill belt speed [m/s]

int rightDelayTime = 200;         // initialize the heel strike delay to 200 ms
int leftDelayTime = 200;          // initialize the heel strike delay to 200 ms

// initialize variables
bool new_stanceL = false;
bool new_stanceR = false;
bool old_stanceL = false;
bool old_stanceR = false;
bool LHS = false;
bool RHS = false;
bool LTO = false;
bool RTO = false;
bool canStim = false;
int phase = 0;  // 0 = Double Support, 1 = single L support, 2 = single R support
int LstepCount = 0;
int RstepCount = 0;
int threshFz = 5;     // 30 N force plate threshold
int numStrides = 10;  // number of steps (not strides) after which to stimulate
int value = 0;

// right stimulator configuration
const int rightSensorPin = A1;
const int rightOutputPin = 8;
const int rightViconOut = 11;

// left stimulator configuration
const int leftSensorPin = A0;
const int leftOutputPin = 9;
const int leftViconOut = 12;

// functions
int rightDelayCalc(float rightTreadmillSpeed) {
  rightDelayTime = (-73.8 * rightTreadmillSpeed) + 384.4;
  return rightDelayTime;
}

int leftDelayCalc(float leftTreadmillSpeed) {
  leftDelayTime = (-73.8 * leftTreadmillSpeed) + 384.4;
  return leftDelayTime;
}

void setup() {
  Serial.begin(600);
  rightDelayTime = rightDelayCalc(rightTreadmillSpeed);
  leftDelayTime = leftDelayCalc(leftTreadmillSpeed);
  Serial.println("\n\n\n\nSTART");
}

void loop() {
  if (Serial.available() > 0){
    value = Serial.read();
    if (value == 1){// stim right
      Serial.println("Entered Right Stim Loop");
      // delay(rightDelayTime);
      digitalWrite(rightOutputPin, HIGH);
      digitalWrite(rightViconOut, HIGH);
      delay(20);
      digitalWrite(rightOutputPin, LOW);
      digitalWrite(rightViconOut, LOW);
      // canStim = false;
    }
    else if (value == 2){ //stim left
      Serial.println("Entered Left Stim Loop");
      // delay(leftDelayTime);
      digitalWrite(leftOutputPin, HIGH);
      digitalWrite(leftViconOut, HIGH);
      delay(20);
      digitalWrite(leftOutputPin, LOW);
      digitalWrite(leftViconOut, LOW);
      // canStim = false;
    } 
  }
  // Serial.println(RstepCount);
}
