// Updated code to stimulate the tibial nerve of both legs for the Spinal
// Adaptation study to measure H-reflexes during split-belt adaptation
// date (started): 20 Mar. 2024
// author(s): SL, NWB

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
int threshFz = 5;    // 30 N force plate threshold
int numStrides = 10;  // number of steps (not strides) after which to stimulate

// right stimulator configuration
const int rightSensorPin = A1;
const int rightOutputPin = 8;
const int rightViconOut = 11;

// left stimulator configuration
const int leftSensorPin = A0;
const int leftOutputPin = 9;
const int leftViconOut = 12;

void setup() {
  Serial.begin(9600);
  Serial.println("\n\n\n\nSTART");
}

void loop() {
  // Serial.println(phase);
  old_stanceL = new_stanceL;
  old_stanceR = new_stanceR;

  // Read inputs from the sensor pins
  float rightSensorVal = analogRead(rightSensorPin);
  Serial.println(rightSensorVal);
  float leftSensorVal = analogRead(leftSensorPin);
  Serial.print(leftSensorVal);
  Serial.println("----L sensor");

  new_stanceL = leftSensorVal > threshFz;  // new stance phase if heel strike detected
  new_stanceR = rightSensorVal > threshFz;

  LHS = new_stanceL && ~old_stanceL;
  RHS = new_stanceR && ~old_stanceR;
  LTO = ~new_stanceL && old_stanceL;
  RTO = ~new_stanceR && old_stanceR;
  // Serial.print("New: ");
  // Serial.println(new_stanceL);
  // Serial.println(old_stanceL);
  // Serial.println(new_stanceL);
  // Serial.println(old_stanceL);
  
  // Serial.println("-----LTO-----");
  // Serial.println(LTO);
  // Serial.println("-----Lhs-----");
  // Serial.println(LHS);

  // Serial.println("-----RTO-----");
  // Serial.println(RTO);
  // Serial.println("-----RHS-----");
  // Serial.println(RHS);

  // state machine: 0 = initial, 1 = single stance L, 2 = single stance R,
  // 3 = double stance from single stance L, 4 = double stance from single R
  switch (phase) {       // process based on current gait phase
    case 0:              // double stance, only the initial phase
      if (RTO) {         // if there is a R toe off event, ...
        phase = 1;       // progress to single stance L
        RstepCount++;    // increment right step count
        Serial.print("1st R: ");
        Serial.println(RstepCount);
      } else if (LTO) {  // if there is a L toe off event, ...
        phase = 2;       // progress to single stance R
        LstepCount++;    // increment left step count
        Serial.print("1st LLLLL: ");
        Serial.println(LstepCount);
      }
      break;
    case 1:         // single stance L
      if (RHS) {    // if R heel strike event, ...
        phase = 3;  // progress to double stance
        // if (LTO) {
        //   Serial.println("I made it here!");
        //   // in case double stance is too short and a full cycle misses the
        //   // phase switch
        //   phase = 2;
        //   LstepCount++;
        // }
        canStim = true;  // enable stimulation
      }
      break;
    case 2:         // single stance R
      if (LHS) {    // if L heel strike event, ...
        phase = 4;  // progress to double stance
        // if (RTO) {
        //   // in case double stance is too short and a full cycle misses the
        //   // phase switch
        //   phase = 1;
        //   RstepCount++;
        // }
        canStim = true;  // enable stimulation
      }
      break;
    case 3:            // double stance, coming from single stance L
      if (LTO) {       // if L toe off event, ...
        phase = 2;     // progress to single stance R
        LstepCount++;  // increment the step counter
        Serial.print("LLLLLL: ");
        Serial.println(LstepCount);
      }
      break;
    case 4:            // double stance, coming from single stance R
      if (RTO) {       // if R toe off event, ...
        phase = 1;     // progress to single stance L
        RstepCount++;  // increment the step counter
        Serial.print("R: ");
        Serial.println(RstepCount);
      }
      break;
    default:
      // it is never possible to enter the default case
      break;
  }

  if ((!(RstepCount % numStrides)) && phase == 2 && canStim) {
    Serial.println("Entered Right Stim Loop");
    digitalWrite(rightOutputPin, HIGH);
    digitalWrite(rightViconOut, HIGH);
    delay(20);
    digitalWrite(rightOutputPin, LOW);
    digitalWrite(rightViconOut, LOW);
    canStim = false;
  }

  if ((!(LstepCount % numStrides)) && phase == 1 && canStim) {
    digitalWrite(leftOutputPin, HIGH);
    digitalWrite(leftViconOut, HIGH);
    delay(20);
    digitalWrite(leftOutputPin, LOW);
    digitalWrite(leftViconOut, LOW);
    canStim = false;
  }
  // Serial.println(RstepCount);
}
