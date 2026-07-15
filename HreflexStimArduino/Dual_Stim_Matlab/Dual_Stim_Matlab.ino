// Updated code to stimulate the tibial nerve of both legs for the Spinal
// Adaptation study to measure H-reflexes during split-belt adaptation
// date (started): 20 Mar. 2024
// author(s): SL, NWB

// ARCHIVED FALLBACK: pairs with MATLAB-timed stim control (no on-board
// gait detection). Degraded, frame-quantized timing; does not meet the
// 50%-single-stance +-5% target. Emergency/hardware-bench use only.
// Active firmware: triggerStimWithGaitStateMachine_SpeedIndependent.

// stimulation pulse duration (ms)
const int durStimPulse = 20;

// right and left stimulator pin configurations
const int pinOutStimL = 9;
const int pinOutViconL = 12;
const int pinOutStimR = 8;
const int pinOutViconR = 11;

int command = 0; // serial communication integer

void setup()
{
  Serial.begin(115200);
  // ensure pins are properly set for output
  pinMode(pinOutStimL, OUTPUT);
  pinMode(pinOutViconL, OUTPUT);
  pinMode(pinOutStimR, OUTPUT);
  pinMode(pinOutViconR, OUTPUT);
}

void loop()
{
  // check for input from MATLAB
  if (Serial.available())
  {
    command = Serial.read();
    switch (command)
    {
    case 1: // stimulate the left leg
      digitalWrite(pinOutStimL, HIGH);
      digitalWrite(pinOutViconL, HIGH);
      delay(durStimPulse);
      digitalWrite(pinOutStimL, LOW);
      digitalWrite(pinOutViconL, LOW);
      break;

    case 2: // stimulate the right leg
      digitalWrite(pinOutStimR, HIGH);
      digitalWrite(pinOutViconR, HIGH);
      delay(durStimPulse);
      digitalWrite(pinOutStimR, LOW);
      digitalWrite(pinOutViconR, LOW);
      break;
    }
  }
}
