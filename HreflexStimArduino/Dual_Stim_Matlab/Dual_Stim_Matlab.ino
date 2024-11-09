// Updated code to stimulate the tibial nerve of both legs for the Spinal
// Adaptation study to measure H-reflexes during split-belt adaptation
// date (started): 20 Mar. 2024
// author(s): SL, NWB

// threshold values
const int stimDuration = 20;      // stimulation pulse duration (ms)

// right stimulator configuration
const int rightOutputPin = 8;
const int rightViconOut = 11;

// left stimulator configuration
const int leftOutputPin = 9;
const int leftViconOut = 12;

void setup() {
  // increased baud rate for faster serial communication
  Serial.begin(9600);
  // ensure pins are properly set for output
  pinMode(rightOutputPin, OUTPUT);
  pinMode(rightViconOut, OUTPUT);
  pinMode(leftOutputPin, OUTPUT);
  pinMode(leftViconOut, OUTPUT);

  Serial.println("\n\n\n\nSTART");
}

void loop() {
  if (Serial.available() > 0) {
    int value = Serial.read();
    if (value == 1) {       // stimulate right leg
      Serial.println("Entered Right Stim Loop");
      digitalWrite(rightOutputPin, HIGH);
      digitalWrite(rightViconOut, HIGH);
      delay(stimDuration);
      digitalWrite(rightOutputPin, LOW);
      digitalWrite(rightViconOut, LOW);
    } 
    else if (value == 2) {  // stimulate left leg
      Serial.println("Entered Left Stim Loop");
      digitalWrite(leftOutputPin, HIGH);
      digitalWrite(leftViconOut, HIGH);
      delay(stimDuration);
      digitalWrite(leftOutputPin, LOW);
      digitalWrite(leftViconOut, LOW);
    }
  }
}

