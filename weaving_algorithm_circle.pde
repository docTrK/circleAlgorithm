//------------------------------------------------------
// circular weaving algorithm
// dan@marginallyclever.com 2016-08-05
// based on work by Petros Vrellis (http://artof01.com/vrellis/works/knit.html)
//------------------------------------------------------

// points around the circle
int numberOfPoints = 188;
// self-documenting
int numberOfLinesToDrawPerFrame = 1;
// self-documenting
int totalLinesToDraw=30000;
// how dark is the string being added.  1...255 smaller is lighter.
int stringAlpha = 45;
// ignore N nearest neighbors to this starting point
int skipNeighbors=10;
// set true to start paused.  click the mouse in the screen to pause/unpause.
boolean paused=true;
// make this true to add one line per mouse click.
boolean singleStep=false;

float CUTOFF=0;

//------------------------------------------------------
// // convenience
color white = color(255, 255, 255);
color black = color(0, 0, 0);
color blue = color(0, 0, 255);
color green = color(0, 255, 0);


//------------------------------------------------------
int numLines = numberOfPoints * numberOfPoints / 2;
float [] intensities = new float[numberOfPoints];
float [] px = new float[numberOfPoints];
float [] py = new float[numberOfPoints];
float [] lengths = new float[numberOfPoints];
PImage img;
PGraphics dest; 

class WeavingThread {
  color c;
  int currentPoint;
  String name;
  
  char [] done;
}

ArrayList<WeavingThread> lines = new ArrayList<WeavingThread>();

int totalLinesDrawn=0;



//------------------------------------------------------
/**
 * To modify this example for another image, you will have to MANUALLY
 * tweak the size() values to match the img.width and img.height.
 * Don't like it?  Tell the Processing team. 
 */
void setup() {
  // the name of the image to load
  img = loadImage("cropped.jpg");
  size(1336, 668);
  dest = createGraphics(img.width, img.height);

  // find average color of image
  float r=0,g=0,b=0;
  int size=img.width*img.height;
  int i;
  for(i=0;i<size;++i) {
    color c=img.pixels[i];
    r+=red(c);
    g+=green(c);
    b+=blue(c);
  }
  dest.beginDraw();
  dest.background(r/(float)size,g/(float)size,b/(float)size);
  dest.endDraw();
  
  // smash the image to grayscale
  img.filter(GRAY);

  // find the size of the circle and calculate the points around the edge.
  float maxr = ( img.width > img.height ) ? img.height/2 : img.width/2;

  for (i=0; i<numberOfPoints; ++i) {
    float d = PI * 2.0 * i/(float)numberOfPoints;
    px[i] = img.width/2 + cos(d) * maxr;
    py[i] = img.height/2 + sin(d) * maxr;
  }

  // a lookup table because sqrt is slow.
  for (i=0; i<numberOfPoints; ++i) {
    float dx = px[i] - px[0];
    float dy = py[i] - py[0];
    lengths[i] = sqrt(dx*dx+dy*dy);
  }
  
  lines.add(addLine(color(255,255,255),"white"));
  lines.add(addLine(color(  0,  0,  0),"black"));
  lines.add(addLine(color(127,127,255),"blue"));
  lines.add(addLine(color(230, 211, 133),"yellow"));
}


WeavingThread addLine(color c,String name) {
  WeavingThread wt = new WeavingThread();
  wt.c=c;
  wt.name=name;
  wt.done = new char[numberOfPoints*numberOfPoints];

  // find best start
  wt.currentPoint = 0; 
  float bestScore = MAX_FLOAT;
  int i,j;
  for(i=0;i<numberOfPoints;++i) {
    for(j=i+1;j<numberOfPoints;++j) {
      float score = scoreLine(i,j,wt);
      if(bestScore>score) {
        bestScore = score;
        wt.currentPoint=i;
      }
    }
  }
  return wt;
}


//------------------------------------------------------
void mouseReleased() {
  paused = paused ? false : true;
}


//------------------------------------------------------
void draw() {
  // if we aren't done
  if (totalLinesDrawn<totalLinesToDraw) {
    if (!paused) {
      // draw a few at a time so it looks interactive.
      int i;
      for (i=0; i<numberOfLinesToDrawPerFrame; ++i) {
        for(int j=0;j<lines.size();++j) {
          drawLine(lines.get(j));
        }
      }
      if (singleStep) paused=true;
    }
    image(img, width/2, 0);
    image(dest, 0, 0);
  }
  // progress bar
  float percent = (float)totalLinesDrawn / (float)totalLinesToDraw;

  strokeWeight(10);  // thick
  stroke(blue);
  line(10, 5, (width-10), 5);
  stroke(green);
  line(10, 5, (width-10)*percent, 5);
  strokeWeight(1);  // default
}


//------------------------------------------------------
/**
 * find the darkest line on the image between two points
 * subtract that line from the source image
 * add that line to the output.
 */
void drawLine(WeavingThread wt) {
  int i, j, k;
  double maxValue = 1000000;
  int maxA = 0;
  int maxB = 0;
  // find the darkest line in the picture

  // starting from the last line added
  i=wt.currentPoint;

  // uncomment this line to choose from all possible lines.  much slower.
  //for(i=0;i<numberOfPoints;++i)
  {
    int i0 = i+1+skipNeighbors;
    int i1 = i+numberOfPoints-skipNeighbors;
    for (j=i0; j<i1; ++j) {
      int nextPoint = j % numberOfPoints;
      if(wt.done[i*numberOfPoints+nextPoint]>0) {
        wt.done[i*numberOfPoints+nextPoint]--;
        wt.done[nextPoint*numberOfPoints+i]--;
        continue;
      }
      float intensity = scoreLine(i,nextPoint,wt);
      double currentIntensity = intensity;
      if ( maxValue > currentIntensity ) {
        maxValue = currentIntensity;
        maxA = i;
        maxB = nextPoint;
      }
    }
  }
  
  if(maxValue>CUTOFF) return;

  println(totalLinesDrawn+" : "+wt.name+"\t"+maxA+"\t"+maxB+"\t"+maxValue);
  
  drawToDest(maxA, maxB, wt.c);
  wt.done[maxA*numberOfPoints+maxB]=20;
  wt.done[maxB*numberOfPoints+maxA]=20;
  totalLinesDrawn++;
  
  // move to the end of the line.
  wt.currentPoint = maxB;
}

float scoreLine(int i,int nextPoint,WeavingThread wt) {
  float dx = px[nextPoint] - px[i];
  float dy = py[nextPoint] - py[i];
  float len = lengths[(int)abs(nextPoint-i)];//Math.floor( Math.sqrt(dx*dx+dy*dy) );

  float diff0=scoreColors(img.get((int)px[i], (int)py[i]),wt.c);
  float s,fx,fy,dc,ic,diff1,change;
  
  // measure how dark is the image under this line.
  float intensity = 0;
  for(int k=0; k<len; ++k) {
    s = (float)k/len; 
    fx = px[i] + dx * s;
    fy = py[i] + dy * s;

    dc = scoreColors(dest.get((int)fx, (int)fy),wt.c);
    ic = scoreColors(img.get((int)fx, (int)fy),wt.c);
    diff1 = ic-dc;
    change=abs(diff0-ic);
    intensity += diff1 + change;  // adjust for high-contrast areas
    diff0=ic;

  }
  return intensity/len;
}

float scoreColors(color a,color b) {
  float dr = red(a)-red(b);
  float dg = green(a)-green(b);
  float db = blue(a)-blue(b);
  return sqrt(dr*dr+dg*dg+db*db);
}

void drawToDest(int start, int end, color c) {
  // draw darkest lines on screen.
  dest.beginDraw();
  dest.stroke(red(c),green(c),blue(c), stringAlpha);
  dest.line((float)px[start], (float)py[start], (float)px[end], (float)py[end]);
  dest.endDraw();
}
