// code for stimulating both legs

// ADJUST THE FOUR PARAMETERS BELOW AS NEEDED.

int threshold = 70; //adjust values based on subject weight.
// guide values: 100-120 lb female (~70), 200 lb male (~140).
// if the Serial Monitor is not printing out steps as people are 
// stepping on the treadmill, the threshold is too high.
//SL 03/20: don't change this value. keep it at 70

int numSteps = 20; //STEPS, NOT STRIDES. 10 STRIDES IS 20 STPES.
//stimulate after how many steps?
// THIS VARIABLE SHOULD BE ADJUSTED FOR EACH SUBJECT INDIVIDUALLY
// THIS VARIABLE SHOULD NOT BE INTERPRETED LITERALLY!!
// count can be off. Adjust based on how often you hear the
// stimulators beep, even if the number doesn't make any sense.
// For example, setting the variable numSteps_target equal to 120
// is okay if people are consistently getting stimulated every
// 5 steps. It can be done better, but the signals are for some 
// reason a bit wonky, but this should be good enough for now.
// Can test these parameters in a TM walking trial.

float rightTreadmillSpeed = 1.00;//0.5592;//1.1183; //Right treadmill belt speed [m/s]
float leftTreadmillSpeed = 1.00;//0.5592;//1.1183; //Left treadmill belt speed [m/s]


// right stims variables
const int rightSensorPin = A1; //original
const int rightOutputPin = 8;
const int rightViconOut = 11;
// const int rightSensorPin = A0; //swapped
// const int rightOutputPin = 8;
// const int rightViconOut = 12; //swapped

bool rightFlag = false;
bool rightPrevFlag = false;
bool rightStims = false;
int rightTemp = 0;
int rightDelayTime = 200;
float rForcePrev = 0;


// left stims variables
const int leftSensorPin = A0; // original
const int leftOutputPin = 9;
const int leftViconOut = 12;
// const int leftSensorPin = A1; //swapped
// const int leftOutputPin = 9;
// const int leftViconOut = 11; //swapped
bool leftFlag = false;
bool leftPrevFlag = false;
bool leftStims = false;
int leftTemp = 0;
int leftDelayTime = 200;
float lForcePrev = 0;
int numSteps_target = 10; 

// universal variable(s)


int steps = 0;
bool TD_r = false; //this is needed to always stimualte R first then L. don't do it at the same time. 
//even though this seems better solved with a L and R counter. 
//also this argument is probably not useful if the code runs in a single thread..


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
  Serial.begin(9600);
  rightDelayTime = rightDelayCalc(rightTreadmillSpeed);
  leftDelayTime = leftDelayCalc(leftTreadmillSpeed);
  // numSteps = (int)(numSteps_target * rightTreadmillSpeed / (0.47 * rightTreadmillSpeed + 0.85));
  Serial.println("START");
}

void loop() {
  // Read inputs from the sensor pins
  float rightSensorVal = analogRead(rightSensorPin);
  Serial.println(rightSensorVal);
  // Serial.print("----- Right Force Plate: ");
  // Serial.println(rightSensorVal);
  // Serial.print("---------------------------------------------");
  float leftSensorVal = analogRead(leftSensorPin);
  // Serial.print("----- Left Force Plate: ");
  // Serial.println(leftSensorVal);
  // Serial.print("---------------------------------------------");
  // Process right leg sensor
  if (rForcePrev <= threshold && rightSensorVal > threshold) { // if there's weight on the treadmill 
    rightFlag = true;

    if (rightFlag != rightPrevFlag) { // new step is happening
      if (TD_r == false){
        if (steps >= numSteps) { //valid step is happening
          Serial.println("VALID _ RIGHT RRRRRRRRRRRRRRRRRRRRRRRR");
          // Changing with the delay:
          delay(rightDelayTime);
          digitalWrite(rightOutputPin, HIGH);   
          digitalWrite(rightViconOut, HIGH);
          delay(20);
          digitalWrite(rightOutputPin, LOW);
          digitalWrite(rightViconOut, LOW);
          TD_r = true;
        }
        else {// new step but not a valid step
          // steps+=1;
          Serial.print("Step_Num_ RRRRR");
          Serial.println(steps);
  
          // nothing should happen (can write digital low)
        }
      }
    }
    steps+=1;
    rightPrevFlag = rightFlag; //the prev flag is needed to avoid coming into the if block and stimulate multiple times in the same stride.
    
  }

  else {
    rightFlag = false;
    rightPrevFlag = false;
  }


  // Process right leg sensor
  if (lForcePrev <= threshold && leftSensorVal > threshold) {
    leftFlag = true;
    if (leftFlag != leftPrevFlag) { // new step is happening
      if (TD_r == true) { 
        if (steps >= numSteps){//valid step is happening
          Serial.println("VALID _ LEFT LLLLLLLLLLLLLLLLLLLLL");
          // Changing with the delay:
          delay(leftDelayTime);
          digitalWrite(leftOutputPin, HIGH);
          digitalWrite(leftViconOut, HIGH);
          delay(20);
          digitalWrite(leftOutputPin, LOW);
          digitalWrite(leftViconOut, LOW);          
          steps = 0;// Make sure to reset
          TD_r = false;
        }
      }
      
      else {
        // steps+=1;
        Serial.print("Non_left");
        Serial.println(steps);
        // nothing should happen (can write digital low)
        }
       
    }
    leftPrevFlag = leftFlag;  
    steps+=1; 
  }
  else{
    leftFlag = false;
    leftPrevFlag = false;
  }
  lForcePrev = leftSensorVal;
  rForcePrev = rightSensorVal; 
}
