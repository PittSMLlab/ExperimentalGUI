// Updated code to stimulate the tibial nerve of both legs for the Spinal
// Adaptation study to measure H-reflexes during split-belt adaptation
// date (started): 20 Mar. 2024
// author(s): SL, NWB

/////////////////////////////////////////////////////////////////////////////
////// THE BELOW TREADMILL SPEEDS MUST BE UPDATED BEFORE EVERY TRIAL ////////
/////////////////////////////////////////////////////////////////////////////
float rightTreadmillSpeed = 0.4;  // right treadmill belt speed [m/s]
float leftTreadmillSpeed = 0.8;   // left treadmill belt speed [m/s]

int rightDelayTime = 200;         // initialize the heel strike delay to 200 ms
int leftDelayTime = 200;          // initialize the heel strike delay to 200 ms

// threshold values
const int threshFz = 5;           // 30 N force plate threshold
const int stimDuration = 20;      // stimulation pulse duration in milliseconds

// right stimulator configuration
const int rightSensorPin = A1;
const int rightOutputPin = 8;
const int rightViconOut = 11;

// left stimulator configuration
const int leftSensorPin = A0;
const int leftOutputPin = 9;
const int leftViconOut = 12;

// functions to calculate delay times based on treadmill speed
int rightDelayCalc(float rightTreadmillSpeed) {
  return (-73.8 * rightTreadmillSpeed) + 384.4;
}

int leftDelayCalc(float leftTreadmillSpeed) {
  return (-73.8 * leftTreadmillSpeed) + 384.4;
}

void setup() {
  Serial.begin(9600);   // increased baud rate for faster serial communication
  // ensure pins are properly set for output
  pinMode(rightOutputPin, OUTPUT);
  pinMode(rightViconOut, OUTPUT);
  pinMode(leftOutputPin, OUTPUT);
  pinMode(leftViconOut, OUTPUT);

  rightDelayTime = rightDelayCalc(rightTreadmillSpeed);
  leftDelayTime = leftDelayCalc(leftTreadmillSpeed);

  Serial.println("\n\n\n\nSTART");
}

void loop() {
  if (Serial.available() > 0) {
    int value = Serial.read();
    if (value == 1) { // stimulate right leg
      Serial.println("Entered Right Stim Loop");
      // uncomment delay below if timing adjustments are needed
      // delay(rightDelayTime);
      digitalWrite(rightOutputPin, HIGH);
      digitalWrite(rightViconOut, HIGH);
      delay(stimDuration);
      digitalWrite(rightOutputPin, LOW);
      digitalWrite(rightViconOut, LOW);
    } 
    else if (value == 2) { // stimulate left leg
      Serial.println("Entered Left Stim Loop");
      // uncomment delay below if timing adjustments are needed
      // delay(leftDelayTime);
      digitalWrite(leftOutputPin, HIGH);
      digitalWrite(leftViconOut, HIGH);
      delay(stimDuration);
      digitalWrite(leftOutputPin, LOW);
      digitalWrite(leftViconOut, LOW);
    }
  }
}

