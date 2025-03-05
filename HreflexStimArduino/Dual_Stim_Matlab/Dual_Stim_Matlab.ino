// Updated code to stimulate the tibial nerve of both legs for the Spinal
// Adaptation study to measure H-reflexes during split-belt adaptation
// date (started): 20 Mar. 2024
// author(s): SL, NWB

// stimulation pulse duration (ms)
const int stimDuration = 20;

// stimulator configuration
const int rightOutputPin = 8;
const int rightViconOut = 11;
const int leftOutputPin = 9;
const int leftViconOut = 12;
int value = 0;  // serial communication integer

void setup() {
  Serial.begin(115200);
  // ensure pins are properly set for output
  pinMode(rightOutputPin, OUTPUT);
  pinMode(rightViconOut, OUTPUT);
  pinMode(leftOutputPin, OUTPUT);
  pinMode(leftViconOut, OUTPUT);
}

void loop() {
  if (Serial.available()) {
    value = Serial.read();
    switch (value)
    {
      case 1:   // stimulate right leg
        digitalWrite(rightOutputPin, HIGH);
        digitalWrite(rightViconOut, HIGH);
        delay(stimDuration);
        digitalWrite(rightOutputPin, LOW);
        digitalWrite(rightViconOut, LOW);
        break;

      case 2:   // stimulate left leg
        digitalWrite(leftOutputPin, HIGH);
        digitalWrite(leftViconOut, HIGH);
        delay(stimDuration);
        digitalWrite(leftOutputPin, LOW);
        digitalWrite(leftViconOut, LOW);
        break;
    }
  }
}

