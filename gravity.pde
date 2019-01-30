import java.awt.Point;

// Instance variables
GObject[] active; // index of all active physics objects
PImage img; // image used for all physics objects
float prevGravity;

// Constants
static final int SIZE = 50;
static final float GRAVITY = 1.0f;
static final float VELOCITY_BOOST = 20.0f;
static final float GRAVITY_INCREMENT = 0.25f;
static final String HELP_TEXT = "Press space to add a new object, and enter to reset the scene.\n" +
                                "Use the up and down arrow keys to increase or decrease gravity,\n" +
                                "backspace toggles it on or off completely." +
                                "Left click gives horizontal velocity to the closest object,\n" +
                                "and right click gives vertical velocity.\n" +
                                "Current gravity: %3.2f\n" +
                                "WARNING: Increasing gravity beyond 1.00 can lead to weird results!";


void setup()
{
  // Set canvas size and background color
  size(1280, 1024);
  background(color(0));
  prevGravity = 0.0f;
  
  // Load physics object image
  img = loadImage("chrome-10.png");
  
  // Create and preload the object index
  active = new GObject[0];
  addObject();
}

void draw()
{
  // Clear the screen
  background(color(0));
  
  // For each active physics object, update its velocity and position, and calculate its collision
  for(GObject g : active){
    g.render();
    g.calculateCollision(width, height);
  }
  
  // Draw instructions
  fill(255);
  text(String.format(HELP_TEXT, active[0].getGravity()), 0, 0, width, height);
}

/**
 * Add a new physics object to the scene.
 */
void addObject()
{
  // Create a temporary array, copy the previous entries to it, add a new entry, and then
  // copy the temporary array back to the original one.
  GObject[] tmp = new GObject[active.length + 1];
  System.arraycopy(active, 0, tmp, 0, active.length);
  tmp[tmp.length - 1] = new GObject(GRAVITY, img, width / 2, 50, SIZE, SIZE);
  active = tmp;
}

/**
 * Reset the scene to its initial state.
 */
void reset()
{
  // Clear the active object array, and add a new default object to it.
  active = new GObject[0];
  addObject();
}

/**
 * Get the index of the closest active physics object to the cursor.
 */ 
int closestObject()
{
  // For each active physics object:
  int closest = 0;
  float minDist = Float.MAX_VALUE;
  for(int i = 0; i < active.length; i++)
  {
    GObject g = active[i];
    Point gc = g.getCoordinates();
    
    // Check to see how far this object is from the cursor
    float diffX = Math.abs(mouseX - gc.x);
    float diffY = Math.abs(mouseY - gc.y);
    
    // Average the two distance values
    float distance = (diffX + diffY) / 2.0f;
    
    // If the compounded distance is less than the previous objects, update the tracking
    // variables and continue.
    if(distance < minDist){
      closest = i;
      minDist = distance;
    }
  }
  
  return closest;
}

/**
 * Gets the multiplier for the boost that a specified physics object should recieve from
 * a mouse click, given its current position relative to the cursor and which axis is being
 * checked for this click.
 */
int getBoostDir(GObject g, boolean isX)
{
  // Determine whether the mouse cursor is positive or negative relative to the object
  // in the specified axis, and return the appropriate multiplier.
  if(isX)
    return mouseX <= g.getCoordinates().x ? 1 : -1;
  else
    return mouseY <= g.getCoordinates().y ? 1 : -1;
}

void mousePressed()
{
  // Boost the velocity of the closest object in the scene if the mouse is clicked.
  // Left mouse gives vertical velocity, right mouse gives horizontal velocity.
  // Boost direction is dependent on where the pointer is relative to the object.
  if(mouseButton == LEFT){
    GObject g = active[closestObject()];
    g.velocityDelta(0.0f, VELOCITY_BOOST * getBoostDir(g, false));
  }else{
    GObject g = active[closestObject()];
    g.velocityDelta(VELOCITY_BOOST * getBoostDir(g, true), 0.0f);
  }
}

void keyPressed()
{
  // Add another object to the scene if the spacebar is pressed
  if(key == ' ') addObject();
  
  // Reset the scene if the enter key is pressed
  else if(keyCode == ENTER || keyCode == RETURN) reset();
  
  // Increase gravity if the up key is pressed
  else if(keyCode == UP){
    for(GObject g : active)
      g.setGravity(g.getGravity() + GRAVITY_INCREMENT);
  }
  
  // Decrease gravity (down to the minimum of GRAVITY_INCREMENT) if the down key is pressed
  else if(keyCode == DOWN){
    for(GObject g : active){
      float gravity = g.getGravity() - GRAVITY_INCREMENT;
      g.setGravity(gravity < GRAVITY_INCREMENT ? GRAVITY_INCREMENT : gravity);
    }
  }
  
  // Toggle gravity on or off if backspace is pressed
  else if(keyCode == BACKSPACE){
    // Cache current gravity
    float gCache = active[0].getGravity();
    // Set all objects to use the previous gravity state
    for(GObject g : active) g.setGravity(prevGravity);
    // Update previous state to cached value
    prevGravity = gCache;
  }
}


class GObject
{
  // Public physics constants
  public static final float Y_IMPACT_PENALTY = 2.0f;
  public static final float X_IMPACT_PENALTY = 2.0f;
  public static final float FRICTION_PENALTY = 0.25f;
  
  // Internal properties
  private PImage graphic; // the image used for this object
  private Point initialCoords; // starting coordinates used for reset
  private Point currentCoords; // current active coordinates
  private float gravity; // gravitational constant
  private float[] velocity; // current instantaneous velocity
  private boolean atRest; // is this object resting against the Y+ boundary, used to prevent
                          // the object spazzing out when it comes to a stop due to gravity
  
  /**
   * Constructs a new physics object.
   * @param gravity the constant gravitational acceleration this object should experience,
   *                in PPF^2 (pixels per frame squared). Values below 0 will be negated.
   * @param graphic the image to display on this physics object
   * @param x the initial X coordinate for this object
   * @param y the initial Y coordinate for this object
   * @param w the width that the provided graphic should be resized to. Values less than or equal to 0 will
              be ignored, and the image's original size will be used instead.
   * @param w the height that the provided graphic should be resized to. Values less than or equal to 0 will
              be ignored, and the image's original size will be used instead.
   */
  public GObject(float gravity, PImage graphic, int x, int y, int w, int h)
  {
    this.gravity = gravity < 0.0f ? -gravity : gravity;
    this.graphic = graphic;
    this.initialCoords = new Point(x, y);
    this.currentCoords = new Point(x, y);
    this.atRest = false;
    
    if(w > 0 && h > 0) graphic.resize(w, h);
    velocity = new float[2];
  }
  
  /**
   * Draws this object to canvas, and updates its internal position, velocity, and gravity calculations.
   */
  public void render()
  {
    // Draw image
    image(graphic, currentCoords.x, currentCoords.y);
    
    // Update next draw coordinates with the current velocity
    currentCoords.x += velocity[0];
    currentCoords.y += velocity[1];
    
    // Account for gravitational acceleration in the Y-axis if the object has not come to a stop in the Y-axis
    if(!atRest) velocity[1] += gravity;
    else{
      // Account for friction in the X-axis if the object has come to a rest along the Y-axis
      float tmp = velocity[0];
      if(Math.abs(tmp) - FRICTION_PENALTY >= 0) tmp -= tmp > 0 ? FRICTION_PENALTY : -FRICTION_PENALTY;
      else tmp = 0.0f;
      velocity[0] = tmp;
    }
  }
  
  /**
   * Calculates collision with the edge of the canvas, and updates velocities accordingly.
   * In a "real-time" simulation, this should be called directly <i>before</i> {@link #render()} is called.
   */ 
  public void calculateCollision(float w, float h)
  {
    if(currentCoords.x + graphic.width >= w) // X+
    { 
      float tmp = velocity[0];
      tmp -= X_IMPACT_PENALTY * 2;
      tmp = tmp < 0.0f ? 0.0f : tmp;
      tmp = -tmp;
      velocity[0] = tmp;
      currentCoords.x = (int)(w - (graphic.width + 1.0f));
    }else if(currentCoords.x <= 0) // X-
    { 
      float tmp = velocity[0];
      tmp += X_IMPACT_PENALTY * 2;
      tmp = tmp > 0.0f ? 0.0f : tmp;
      tmp = -tmp;
      velocity[0] = tmp;
      currentCoords.x = 1;
    }
    
    if(currentCoords.y + graphic.height > h) // Y+
    {
      float tmp = velocity[1];
      tmp -= Y_IMPACT_PENALTY * 2;
      tmp = tmp < 0.0f ? 0.0f : tmp;
      if(tmp == 0.0f) atRest = true;
      tmp = -tmp;
      velocity[1] = tmp;
      currentCoords.y = (int)(h - (graphic.height + 1.0f));
    }else if(currentCoords.y <= 0) // Y-
    {
      float tmp = velocity[1];
      tmp += Y_IMPACT_PENALTY * 2;
      tmp = tmp > 0.0f ? 0.0f : tmp;
      tmp = -tmp;
      velocity[1] = tmp;
      currentCoords.y = 1;
    }
  }
  
  /**
   * Gets the gravitational constant being applied to this object, in PPF^2 (pixels per frame squared).
   */
  public float getGravity(){
    return gravity;
  }
  
  /**
   * Sets the gravitational constant for this object, where 0 is floating with no gravity.
   * @param gravity the gravitational constant to be applied to this object, in PPF^2 (pixels per frame squared)
   */
  public void setGravity(float gravity){
    this.gravity = gravity;
  }
  
  /**
   * Gets the current instantaneous velocity of this object in the X,Y axes.
   * @returns a length-2 array containing this object's velocities in the [x,y] axes, in that order
   */ 
  public float[] getVelocity(){
    return new float[]{velocity[0], velocity[1]};
  }
  
  /**
   * Gets this object's current X,Y coordinates.
   */
  public Point getCoordinates(){
    return new Point(currentCoords.x, currentCoords.y);
  }
  
  /**
   * Sets the current instantaneous velocity of this object to the specified X,Y values.
   * @param x the horizontal velocity of this object
   * @param y the vertical velocity of this object (note: affected by gravity unless setGravity(0.0f) is called)
   */
  public void setVelocity(float x, float y){
    this.velocity[0] = x;
    this.velocity[1] = y;
    if(y > 0.0f) atRest = false;
  }
  
  /**
   * Adds the specified amount of momentum to this object in the X,Y axes.
   * @param x the velocity to add to this object in the horizontal axis
   * @param y the velocity to add to this object in the vertical axis (note: affected by gravity unless setGravity(0.0f) is called)
   */
  public void velocityDelta(float x, float y){
    this.velocity[0] += x;
    this.velocity[1] += y;
    if(atRest && Math.abs(y) > 0.0f) atRest = false;
  }
  
  /**
   * Resets this object to its original position, and negates any velocity it may have had.
   * Does not update its actual position until render() is called.
   */
  public void reset()
  {
    velocity[0] = 0.0f;
    velocity[1] = 0.0f;
    currentCoords.x = initialCoords.x;
    currentCoords.y = initialCoords.y;
    atRest = false;
  }
}
