// code for stimulating both legs at once

// right stims variables
const int rightSensorPin = A1;
const int rightOutputPin = 8;
const int rightViconOut = 11;
bool rightFlag = false;
bool rightPrevFlag = false;
bool rightStims = false;
int rightTemp = 0;
int rightDelayTime = 200;
float rightTreadmillSpeed = 1.0; 

// left stims variables
const int leftSensorPin = A0;
const int leftOutputPin = 9;
const int leftViconOut = 12;
bool leftFlag = false;
bool leftPrevFlag = false;
bool leftStims = false;
int leftTemp = 0;
int leftDelayTime = 200;
float leftTreadmillSpeed = 0.5;

// universal variable(s)
int numSteps = 6;
int steps = 0;
bool TD_r = false;
int threshold = 80;

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
  numSteps = (int)(10 * rightTreadmillSpeed / (0.47 * rightTreadmillSpeed + 0.85));
  Serial.println("START");
}

void loop() {

  // Read inputs from the sensor pins
  float rightSensorVal = analogRead(rightSensorPin);
  float leftSensorVal = analogRead(leftSensorPin);
  // Process right leg sensor
  if (rightSensorVal > threshold) { // if there's weight on the treadmill 
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
          steps+=1;
          Serial.print("Step_Num_ RRRRR");
          Serial.println(steps);
  
          // nothing should happen (can write digital low)
        }
      }
    }
    rightPrevFlag = rightFlag;
  }

  else{
    rightFlag = false;
    rightPrevFlag = false;
  }


  // Process right leg sensor
  if (leftSensorVal > threshold) {
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
        steps+=1;
        Serial.print("Non_left");
        Serial.println(steps);
        // nothing should happen (can write digital low)
        }
       
    }
    leftPrevFlag = leftFlag;   
  }
  else{
    leftFlag = false;
    leftPrevFlag = false;
  }
}
