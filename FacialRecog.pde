/**
Project Description: A facial recognition program using opencv and processing. On
load select webcam or video. Press spacebar to pause. Click on face to rename 
and enter to confirm. 
*/

import gab.opencv.*;
import processing.video.*;
import java.awt.*;
import java.util.HashMap;
import javax.swing.JFileChooser;
import java.io.File;

Capture cam;
Movie mov;
OpenCV opencv;
float scaleRatio;
boolean isPaused = false;
Rectangle[] faces;
int selectedFace = -1;
HashMap<Integer, String> faceLabels = new HashMap<>();
HashMap<Integer, Rectangle> lastKnownPositions = new HashMap<>();
String currentInput = "";
int nextFaceID = 0;
HashMap<Rectangle, Integer> currentFaceIDs = new HashMap<>();

// Input selection variables
boolean inputSelected = false;
boolean usingWebcam = false;
boolean webcamAvailable = false;

void setup() {
  size(640, 480);
  
  // Check if any camera is available
  String[] cameras = Capture.list();
  webcamAvailable = cameras != null && cameras.length > 0;
  
  faces = new Rectangle[0];
}

void draw() {
  // Input selection screen
  if (!inputSelected) {
    background(0);
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(24);
    text("Choose Input Source:", width/2, 50);
    
    // Video file option
    fill(200);
    rect(width/2 - 200, height/2 - 60, 400, 50);
    fill(0);
    textSize(20);
    text("Video File", width/2, height/2 - 35);
    
    // Webcam option (only if available)
    if (webcamAvailable) {
      fill(200);
      rect(width/2 - 200, height/2 + 10, 400, 50);
      fill(0);
      text("Webcam", width/2, height/2 + 35);
    } else {
      fill(100);
      rect(width/2 - 200, height/2 + 10, 400, 50);
      fill(255, 0, 0);
      text("No Webcam Available", width/2, height/2 + 35);
    }
    
    return;
  }
  
  // Clear background once input is selected
  if (frameCount == 1 || (usingWebcam && cam == null) || (!usingWebcam && mov == null)) {
    background(0);
    return;
  }
  
  // Check if video has ended and loop it
  if (!usingWebcam && mov.time() >= mov.duration() - 0.1) {
    mov.jump(0);
    mov.play();
  }
  
  if (opencv == null) {
    if (usingWebcam) {
      opencv = new OpenCV(this, cam.width, cam.height);
    } else {
      opencv = new OpenCV(this, mov.width, mov.height);
    }
    opencv.loadCascade(OpenCV.CASCADE_FRONTALFACE);
  }
  
  float widthRatio = (float)width / (usingWebcam ? cam.width : mov.width);
  float heightRatio = (float)height / (usingWebcam ? cam.height : mov.height);
  scaleRatio = min(widthRatio, heightRatio);
  
  float newWidth = (usingWebcam ? cam.width : mov.width) * scaleRatio;
  float newHeight = (usingWebcam ? cam.height : mov.height) * scaleRatio;
  float xOffset = (width - newWidth) / 2;
  float yOffset = (height - newHeight) / 2;
  
  if (!isPaused) {
    if (usingWebcam && cam.available()) {
      cam.read();
      opencv.loadImage(cam);
    } else if (!usingWebcam) {
      opencv.loadImage(mov);
    }
    faces = opencv.detect();
    updateFaceTracking(faces);
  }
  
  // Clear background before drawing new frame
  background(0);
  
  // Display the image
  if (usingWebcam) {
    image(cam, xOffset, yOffset, newWidth, newHeight);
  } else {
    image(mov, xOffset, yOffset, newWidth, newHeight);
  }
  
  // Draw face rectangles and labels
  noFill();
  stroke(0, 255, 0);
  strokeWeight(3);
  
  for (int i = 0; i < faces.length; i++) {
    float scaledX = faces[i].x * scaleRatio + xOffset;
    float scaledY = faces[i].y * scaleRatio + yOffset;
    float scaledW = faces[i].width * scaleRatio;
    float scaledH = faces[i].height * scaleRatio;
    
    if (i == selectedFace) {
      stroke(255, 0, 0);
    } else {
      stroke(0, 255, 0);
    }
    
    rect(scaledX, scaledY, scaledW, scaledH);
    
    int persistentID = currentFaceIDs.getOrDefault(faces[i], -1);
    
    fill(i == selectedFace ? color(255, 0, 0) : color(0, 255, 0));
    textSize(18);
    textAlign(CENTER);
    String label = faceLabels.containsKey(persistentID) ? faceLabels.get(persistentID) : "ID: " + persistentID;
    text(label, scaledX + scaledW/2, scaledY - 10);
    noFill();
  }
  
  // Display instructions and status
  fill(255);
  textAlign(LEFT);
  textSize(14);
  text("Space: " + (usingWebcam ? "Freeze/Unfreeze" : "Pause/Play") + 
       " | Click face to select and rename | Enter to confirm", 10, height - 10);
  text("Status: " + (isPaused ? (usingWebcam ? "FROZEN" : "PAUSED") : "ACTIVE"), 10, height - 30);
  
  if (selectedFace != -1 && !currentInput.isEmpty()) {
    fill(255);
    textAlign(CENTER);
    text("New name: " + currentInput, width/2, height - 30);
  }
  
  // Display video time if using video file
  if (!usingWebcam && mov != null) {
    fill(255);
    textAlign(RIGHT);
    text(nf(floor(mov.time()/60), 2) + ":" + nf(floor(mov.time()%60), 2) + " / " + 
         nf(floor(mov.duration()/60), 2) + ":" + nf(floor(mov.duration()%60), 2), width - 10, height - 30);
  }
}

float distanceBetweenFaces(Rectangle face1, Rectangle face2) {
  float centerX1 = face1.x + face1.width/2;
  float centerY1 = face1.y + face1.height/2;
  float centerX2 = face2.x + face2.width/2;
  float centerY2 = face2.y + face2.height/2;
  
  return dist(centerX1, centerY1, centerX2, centerY2);
}

void updateFaceTracking(Rectangle[] newFaces) {
  // Clear current frame's face IDs
  currentFaceIDs.clear();
  
  // Try to match new faces with known positions
  for (Rectangle newFace : newFaces) {
    float bestDistance = 100; // Threshold for matching
    int bestMatchID = -1;
    
    // Check against all known positions
    for (int id : lastKnownPositions.keySet()) {
      Rectangle lastPos = lastKnownPositions.get(id);
      float distance = distanceBetweenFaces(newFace, lastPos);
      
      if (distance < bestDistance) {
        bestDistance = distance;
        bestMatchID = id;
      }
    }
    
    // If no match found, assign new ID
    if (bestMatchID == -1) {
      bestMatchID = nextFaceID++;
    }
    
    // Update the mappings
    currentFaceIDs.put(newFace, bestMatchID);
    lastKnownPositions.put(bestMatchID, newFace);
  }
}

void keyPressed() {
  if (key == ' ') {
    isPaused = !isPaused;
    if (isPaused) {
      if (!usingWebcam) mov.pause();
    } else {
      if (!usingWebcam) mov.play();
      selectedFace = -1;
      currentInput = "";
    }
  } else if (selectedFace != -1 && isPaused) {
    if (key == BACKSPACE && currentInput.length() > 0) {
      currentInput = currentInput.substring(0, currentInput.length() - 1);
    } else if (key == ENTER || key == RETURN) {
      if (!currentInput.isEmpty()) {
        int persistentID = currentFaceIDs.get(faces[selectedFace]);
        faceLabels.put(persistentID, currentInput);
        println("Changed face " + persistentID + " to: " + currentInput);
        currentInput = "";
        selectedFace = -1;
      }
    } else if ((key >= 'a' && key <= 'z') || (key >= 'A' && key <= 'Z') || 
               (key >= '0' && key <= '9') || key == ' ') {
      currentInput += key;
      println("Current input: " + currentInput);
    }
  }
}

void mousePressed() {
  if (!inputSelected) {
    // Check for video file selection
    if (mouseY >= height/2 - 60 && mouseY <= height/2 - 10 &&
        mouseX >= width/2 - 200 && mouseX <= width/2 + 200) {
      selectInput("Select a video file:", "fileSelected");
    }
    
    // Check for webcam selection
    if (webcamAvailable && 
        mouseY >= height/2 + 10 && mouseY <= height/2 + 60 &&
        mouseX >= width/2 - 200 && mouseX <= width/2 + 200) {
      usingWebcam = true;
      String[] cameras = Capture.list();
      cam = new Capture(this, cameras[0]); // Use first available camera
      cam.start();
      inputSelected = true;
      background(0); // Clear menu screen
    }
    return;
  }
  
  if (!isPaused) return;
  
  float xOffset = (width - ((usingWebcam ? cam.width : mov.width) * scaleRatio)) / 2;
  float yOffset = (height - ((usingWebcam ? cam.height : mov.height) * scaleRatio)) / 2;
  
  for (int i = 0; i < faces.length; i++) {
    float scaledX = faces[i].x * scaleRatio + xOffset;
    float scaledY = faces[i].y * scaleRatio + yOffset;
    float scaledW = faces[i].width * scaleRatio;
    float scaledH = faces[i].height * scaleRatio;
    
    if (mouseX >= scaledX && mouseX <= scaledX + scaledW &&
        mouseY >= scaledY && mouseY <= scaledY + scaledH) {
      selectedFace = i;
      currentInput = "";
      println("Selected face " + i);
      return;
    }
  }
  selectedFace = -1;
}

void fileSelected(File selection) {
  if (selection == null) {
    println("Window was closed or user hit cancel.");
  } else {
    println("User selected " + selection.getAbsolutePath());
    mov = new Movie(this, selection.getAbsolutePath());
    mov.play();
    mov.volume(0);
    usingWebcam = false;
    inputSelected = true;
    background(0); // Clear menu screen
  }
}

void movieEvent(Movie m) {
  m.read();
}
