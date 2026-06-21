/**
 * 下腿アバタ表示アプリ
 * 卒業研究用に開発
 *
 * 黄緑色マーカーをカメラで検出し、
 * 足の上下動に応じてアバターを連動させる
 * 脅威物体3種とボールが接触する映像の提示
 *
 * ※大画面前提のため小画面ではレイアウトが崩れます
 */

import gab.opencv.*;
import processing.video.*;
import java.awt.Rectangle;
import processing.sound.*;
import org.opencv.core.Mat;
import org.opencv.core.Scalar;
import org.opencv.core.Core;
import processing.serial.*;

Capture video;
OpenCV opencv;
PImage src, colorFilteredImage;
ArrayList<Contour> contours;

boolean flag = false;
float scale = 1.0;
float meterWidth, meterHeight, meterX, meterY;
float legX;
float legY;

PImage legImage;
PImage knifeHandImage;
PImage axeImage;
PImage hammerImage;
PImage ballImage;

int m =0;

int startTime = 0;
boolean timerStarted = false;
boolean okDisplayed = false;
int okStartTime = 0;
boolean showOK = false;
int okCount = 0;
float boxTop;
float boxHeight;
float boxBottom;

//ナイフ
int playAnimation = 0;
boolean legLocked = false;
float lockedLegY = 0;
float angleEasing = 0.3;
float knifeHandX;
float knifeHandY;
float knifeSpeed = 20;
float gravity = 1.5;
int knifeStopTime = 0;
boolean knifeVisible = false;

//斧
float axeX, axeY;
float axeSpeed = 20;
float axeGravity = 1.5;
boolean axeVisible = false;
int axeStopTime = 0;
int playAxeAnimation = 0;
float axeAngle = radians(45);

//ハンマー
float hammerX, hammerY;
float hammerSpeed = 20;
float hammerGravity = 1.5;
boolean hammerVisible = false;
int hammerStopTime = 0;
int playHammerAnimation = 0;

//ボール
float ballX, ballY;
float ballSpeed = 20;
float ballGravity = 1.5;
boolean ballVisible = false;
int ballStopTime = 0;
int playBallAnimation = 0;
int actionCount = 0;
boolean knifeUsed = false;

int currentAction = 0;
int sequenceStartTime;
boolean running = false;
boolean justFinished = false;
boolean waiting = false;
int waitStartTime = 0;
int waitTime = 0;
boolean analysisPaused = false;


int duration = 5000;
int[] sequence = {4, 4, 4, 3};
Serial myPort;
SoundFile pinpon;
Mat hueMask, satMask, valMask, mask;

void setup() {
  frameRate(60);
  video = new Capture(this, "pipeline:autovideosrc");
  video.start();

  opencv = new OpenCV(this, video.width, video.height);
  contours = new ArrayList<Contour>();

  fullScreen();
  scale=height/480.0;
  legImage = loadImage("legG.png");
  imageMode(CENTER);

  pinpon = new SoundFile(this, "pin_pon.mp3");
  knifeHandImage = loadImage("knife_handG.png");
  axeImage = loadImage("onoG.png");
  hammerImage = loadImage("hammerG.png");
  ballImage = loadImage("ballG.png");

  printArray(Serial.list());
  myPort = new Serial(this, Serial.list()[1], 9600);
  hueMask = new Mat();
  satMask = new Mat();
  valMask = new Mat();
  mask = new Mat();
}

void keyPressed() {
  if (key == ' ' && !running) {
    lockedLegY = legY;
    analysisPaused = true;
    sequenceStartTime = millis();
    running = true;
    currentAction = 0;
    startAction(sequence[currentAction]);
  }
}
void draw() {
  meterWidth = width * 0.14;
  meterHeight = height * 0.7;
  meterX = width * 0.2 - meterWidth / 2;
  meterY = height * 0.2;
  legX = width * 0.65;
  if (analysisPaused) {
    video.stop();
  }

  if (!analysisPaused) {
    if (video.available()) {
      video.read();
    }
    opencv.loadImage(video);
    opencv.useColor();
    src = opencv.getSnapshot();
    opencv.useColor(HSB);
    Mat h = opencv.getH();
    Mat s = opencv.getS();
    Mat v = opencv.getV();
    Core.inRange(h, new Scalar(30), new Scalar(70), hueMask);
    Core.inRange(s, new Scalar(100), new Scalar(255), satMask);
    Core.inRange(v, new Scalar(50), new Scalar(255), valMask);
    Core.bitwise_and(hueMask, satMask, mask);
    Core.bitwise_and(mask, valMask, mask);
    opencv.setGray(mask);
    colorFilteredImage = opencv.getSnapshot();
    if (frameCount % 2 == 0) {
      contours = opencv.findContours(true, true);
    }
  }
  if (flag) {
    background(128);
  }
  if (contours.size() > 0) {
    Contour biggestContour = contours.get(0);
    Rectangle r = biggestContour.getBoundingBox();
    pushMatrix();
    noStroke();
    fill(255, 0, 0);
    float R = (r.y + r.height / 2) * scale;
    boolean legIsInsideBox = legY+height*0.5 < boxBottom;
    if (legIsInsideBox) {
      fill(180, 255, 180, 100); // 横長い黄緑色の四角形
    } else {
      fill(255, 255, 255, 60); // 横長い白色の四角形
    }
    boxHeight = height * 0.15;
    boxBottom = height*1.5/5;
    boxTop = boxBottom-boxHeight;
    rect(0, boxTop, width, boxHeight);

    fill(255);
    rect(meterX, meterY, meterWidth, meterHeight);
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(height * 0.05);
    text(okCount + "/10", width/5, height/5 - 100);
    if (flag) {
      if (legY+height*0.5< height*1.5/5 && !timerStarted) {
        startTime = millis();
        timerStarted = true;
        okDisplayed = false;
      }
      if (timerStarted) {
        int elapsed = millis() - startTime;
        m = int(map(elapsed, 0, duration, 0, meterHeight));
        m = constrain(m, 0, int(meterHeight));
        rect(meterX, meterY + meterHeight - m, meterWidth, m);
        fill(165, 238, 255);
        rect(meterX, meterY + meterHeight - m, meterWidth, m);
        if (m >= int(meterHeight) && !okDisplayed) {
          okDisplayed = true;
          showOK = true;
          okStartTime = millis();
          okCount++;
          pinpon.play();
        }
      }
      if (okDisplayed && R > height*2/3) {
        timerStarted = false;
        m = 0;
      }
    }


    if (showOK) {
      if (millis() - okStartTime < 2000) {
        pushMatrix();
        fill(255);
        textAlign(CENTER, CENTER);
        textSize(height*0.08);
        text("OK", width / 2, height / 2);
        popMatrix();
      } else {
        showOK = false;
      }
    }
    if (playAnimation == 1) {
      knifeSpeed += 8+gravity*1.1*1.1*1.4*1.4*1.4*1.4*1.4*1.4*1.4;
      knifeHandY += knifeSpeed;

      hint(DISABLE_DEPTH_TEST);
      blendMode(BLEND);

      pushMatrix();
      translate(knifeHandX, knifeHandY);
      image(knifeHandImage, knifeHandImage.width/2, 0);
      popMatrix();
      if (knifeHandY > legY+520) {
        knifeHandY = legY+780;
        playAnimation = 0;
        knifeStopTime = millis();
        knifeVisible = true;
      }
    }
    if (knifeVisible) {
      if (millis() - knifeStopTime < 5000) {
        pushMatrix();
        translate(knifeHandX, knifeHandY);
        image(knifeHandImage, knifeHandImage.width / 2, 0);
        popMatrix();
      } else {
        knifeVisible = false;
        justFinished = true;
      }
    }
    if (playAxeAnimation == 1) {
      //float dt = 1.0/60.0;
      //int skipFrames = 6;
      axeSpeed += 8+axeGravity*1.1*1.1*1.4*1.4*1.4*1.4*1.4*1.4*1.4;
      axeY += axeSpeed;
      //axeY= axeSpeed *dt+0.5*dt*dt;

      pushMatrix();
      translate(axeX, axeY);
      rotate(axeAngle);
      image(axeImage, axeImage.width / 2, 0);
      popMatrix();

      if (axeY > legY-800) {
        axeY = legY-580 ;
        playAxeAnimation = 0;
        axeStopTime = millis();
        axeVisible = true;
      }
    }

    if (axeVisible) {
      if (millis() - axeStopTime < 5000) {
        pushMatrix();
        translate(axeX, axeY);
        rotate(axeAngle);
        image(axeImage, axeImage.width / 2, 0);
        popMatrix();
      } else {
        axeVisible = false;
        justFinished = true;
      }
    }

    if (playHammerAnimation == 1) {
      hammerSpeed += 8+hammerGravity*1.1*1.1*1.4*1.4*1.4*1.4*1.4*1.4*1.4;
      hammerY += hammerSpeed;

      pushMatrix();
      translate(hammerX, hammerY);
      image(hammerImage, hammerImage.width / 2, 0);
      popMatrix();

      if (hammerY > legY+680) {
        hammerY = legY+900 ;
        playHammerAnimation = 0;
        hammerStopTime = millis();
        hammerVisible = true;
      }
    }
    if (hammerVisible) {
      if (millis() - hammerStopTime < 5000) {
        pushMatrix();
        translate(hammerX, hammerY);
        image(hammerImage, hammerImage.width / 2, 0);
        popMatrix();
      } else {
        hammerVisible = false;
        justFinished = true;
      }
    }

    if (playBallAnimation == 1) {
      ballSpeed += 8+ballGravity*1.1*1.1*1.4*1.4*1.4*1.4*1.4*1.4*1.4;
      ballY += ballSpeed;

      pushMatrix();
      translate(ballX, ballY);
      image(ballImage, ballImage.width / 2, 0);
      popMatrix();

      if (ballY > legY+600) {
        ballY = legY+760 ;
        playBallAnimation = 0;
        ballStopTime = millis();
        ballVisible = true;
      }
    }
    if (ballVisible) {
      if (millis() - ballStopTime < 5000) {
        pushMatrix();
        translate(ballX, ballY);
        image(ballImage, ballImage.width / 2, 0);
        popMatrix();
      } else {
        ballVisible = false;
        justFinished = true;
      }
    }
    if (running) {
      if (millis() - sequenceStartTime > 40000) {
        println("時間オーバー");
        running = false;
      }
      if (!knifeVisible && !ballVisible &&
        !axeVisible && !hammerVisible &&
        !waiting && justFinished) {
        justFinished = false;
        if (currentAction < sequence.length-1) {
          waiting = true;
          waitStartTime = millis();
          waitTime = int(random(1500, 3000));
          println("次まで " + waitTime + " ms 待機");
        } else {
          println("シーケンス終了");
          running = false;
        }
      }

      if (waiting && millis() - waitStartTime >= waitTime) {
        waiting = false;
        currentAction++;
        startAction(sequence[currentAction]);
      }
    }

    if (legY + height*0.5>-height*1/5 && R<height*4.2/5) {
      image(legImage, legX, legY);
    }
    popMatrix();
  }
}

void mousePressed() {
  flag =true;
  timerStarted = false;
  okDisplayed = false;
  showOK = false;
}

void movieEvent(Movie m) {
  m.read();
}

void startAction(int action) {
  if (action == 1) { // ナイフ
    playAnimation = 1;
    knifeHandX = legX - 2600;
    knifeHandY = -knifeHandImage.height;
    knifeSpeed = 0;
    legLocked = true;
    lockedLegY = legY;
    myPort.write('1');
  } else if (action == 2) { // 斧
    playAxeAnimation = 1;
    axeX = legX - 2500;
    axeY = -axeImage.height;
    axeSpeed = 0;
    legLocked = true;
    lockedLegY = legY;
    myPort.write('2');
  } else if (action == 3) { // ハンマー
    playHammerAnimation = 1;
    hammerX = legX - 2800;
    hammerY = -hammerImage.height + 400;
    hammerSpeed = 0;
    legLocked = true;
    lockedLegY = legY;
    myPort.write('3');
  } else if (action == 4) { // ボール
    playBallAnimation = 1;
    ballX = legX - 920;
    ballY = -ballImage.height+300;
    ballSpeed = 0;
    legLocked = true;
    lockedLegY = legY;
    myPort.write('4');
  }
}
