// SkiiFree'd - KATKO 2017
//=============================================================================
/*
	QUESTION
		- What if we made this into an ISOMETRIC('ish) game? 
			- It needs to be SHARPLY angled since we're travelling you know... down. 
			- Any games we can think of?

	TODO
		+ DRAW TREES in Z-ORDER so they don't overlap wrong (>>>simply sort objec list?) 
		+ Scrolling
		+ Viewports
		- HOLDING KEYS instead of tapping them? 
			- (wait, shouldn't they auto accelerate? So we only want KEYS to mean MODE).
		- Jumping, ramps, other objects
		- Monsters
		- BOUNDING COLLISION BOXES (also draw collision boxes?)

	NEW FEATURES
		- New enemies?
		- CLIFFS
		- New obsticles?
		- New... stuff?
		- WEATHER?
		- Water/ponds/cliffs?
*/
// http://www.everything2.com/title/Skifree

import std.stdio;
import std.conv;
import std.string;
import std.format; //String.Format like C#?! Nope. Damn, like printf.

import std.random;
import std.algorithm;

pragma(lib, "dallegro5");

version(ALLEGRO_NO_PRAGMA_LIB)
{

}else{
	pragma(lib, "allegro");
	pragma(lib, "allegro_primitives");
	pragma(lib, "allegro_image");
	pragma(lib, "allegro_font");
	pragma(lib, "allegro_ttf");
	pragma(lib, "allegro_color");
}
import allegro5.allegro;
import allegro5.allegro_primitives;
import allegro5.allegro_image;
import allegro5.allegro_font;
import allegro5.allegro_ttf;
import allegro5.allegro_color;

// CONSTANTS
//=============================================================================
immutable float JUMP_VELOCITY = 2.2F; //NYI

//world dimensions
immutable float maximum_x = 2000F; 	//NYI
immutable float maximum_y = 20000F; //NYI
immutable float maximum_z = 100F; 	//NYI

//player constants
immutable float SPEED_FACTOR = 4.0F; //scales UP/down all speeds.
immutable float speed_change_rate = .1F * SPEED_FACTOR; 	//NYI
immutable float speed_maximum	  =  1.3F * SPEED_FACTOR; 	//NYI
immutable float player_jump_velocity = 10.0F; 	//NYI


// Should this be IMMUTABLE? Are there any UPDATED DEPENDANT CONSTANTS we'll need to UPDATE
// once this changes?
// We COULD have a "dependant variables" class that auto-updates the chain of constants
// whenever the top variable change. a TREE STRUCTURE. Hmm.... that could be fun to write...
int SCREEN_W = 1200;
int SCREEN_H = 600;

enum 
	{
	DIR_SINGLE_FRAME	= -3, //note
	DIR_FULL_LEFT 		= -3, //note
	DIR_FAR_ANGLE_LEFT 	= -2,
	DIR_ANGLE_LEFT 		= -1,
	DIR_DOWN 			= 0,
	DIR_ANGLE_RIGHT 	= 1,
	DIR_FAR_ANGLE_RIGHT = 2,
	DIR_FULL_RIGHT 		= 3,
	}

immutable float [7] v_speeds = 
	[
	0, 
	0.1F/4, 
	0.1F/2, 
	0.1F,
	0.1F/2,
	0.1F/4,
	0
	];

immutable float [7] h_speeds = 
	[
	-0.1F, 
	-0.1F/2, 
	-0.1F/4, 
	0,
	0.1F/4,
	0.1F/2,
	0.1F
	];

immutable float [7] v_to_h_conversion = 
	[
	-1.0, 
	-0.8, 
	-0.6, 
	 0.0,
	 0.6,
	 0.8,
	 1.0
	];


//GLOBALS
//=============================================================================
ALLEGRO_CONFIG* 		cfg;  //whats this used for?
ALLEGRO_DISPLAY* 		al_display;
ALLEGRO_EVENT_QUEUE* 	queue;

ALLEGRO_COLOR 			color1;
ALLEGRO_COLOR 			color2;
ALLEGRO_BITMAP* 		bmp;
ALLEGRO_FONT* 			font;

animation_t player_anim;
animation_t monster_anim;
animation_t tree_anim;
animation_t jump_anim;

keyset_t [2] player_controls;
world_t world;
viewport_t [2] viewports;
ALLEGRO_TIMER *fps_timer;

int mouse_x; //cached, obviously. for helper routines.
int mouse_y;

xy_pair target;

struct xy_pair
	{
	int x;
	int y;
	}

display_t display;

// Is there any way we can have global variables in a NAMESPACE (use a module?)
// Or is the single dereference NOT a big deal to pass tbe "globals struct"
// to every main function...

struct statistics_t
	{
	int number_of_drawn_objects;
	int number_of_drawn_background_tiles;
	int fps;
	int frames_passed;
	}

statistics_t stats;

//=============================================================================

class animation_t
	{
	bool has_loaded_a_frame;
	ALLEGRO_BITMAP *[] frames;
	string [] names;
	
	int get_width()
		{
		assert(has_loaded_a_frame, "Did you remember to ADD a frame before calling get_width()?");
		return al_get_bitmap_width(frames[0]);
		}
		
	int get_height()
		{
		assert(has_loaded_a_frame, "Did you remember to ADD a frame before calling get_height()?");
		return al_get_bitmap_height(frames[0]);
		}

	void load_extra_frame(string path)
		{
		ALLEGRO_BITMAP *extra_frame = al_load_bitmap( toStringz(path));
		frames ~= extra_frame;
		//names = to!string(); 
		names ~= "OOPS."; //filler, what happens if not unique? Return first result?
		has_loaded_a_frame = true;
		}
		
	void load_extra_frame_mirrored(string path)
		{
		ALLEGRO_BITMAP *original_frame = al_load_bitmap( toStringz(path));
		ALLEGRO_BITMAP *extra_frame = al_create_bitmap(al_get_bitmap_width(original_frame), al_get_bitmap_height(original_frame));
		
		al_set_target_bitmap(extra_frame);		
		al_draw_bitmap(original_frame, 0, 0, ALLEGRO_FLIP_HORIZONTAL);
		al_set_target_bitmap(al_get_backbuffer(al_display)); //set back to original.
		
		
		
		frames ~= extra_frame;
		//names = to!string(); 
		names ~= "OOPS."; //filler, what happens if not unique? Return first result?
		has_loaded_a_frame = true;
		}


	void load_extra_frame(string path, string name)
		{
		ALLEGRO_BITMAP *extra_frame = al_load_bitmap( toStringz(path));
		frames ~= extra_frame;
		names ~= name;
		has_loaded_a_frame = true;
		}
		
	ALLEGRO_BITMAP* get_frame_by_number(int i)
		{
		ALLEGRO_BITMAP* x;
		return x;
		}
	ALLEGRO_BITMAP* get_frame_by_name(string name)
		{
		ALLEGRO_BITMAP* x;
		return x;
		}
	
	void draw(int frame, float x, float y)
		{
		stats.number_of_drawn_objects++;
		al_draw_bitmap(frames[frame], x, y, 0);
		}

	void draw_centered(int frame, float x, float y)
		{
		stats.number_of_drawn_objects++;
		al_draw_bitmap(frames[frame], x + get_width()/2, y + get_height()/2, 0);
		
		static if (false) // Draw bordering dots
			{
			//top left
			draw_target_dot(  
				to!(int)(x + get_width()/2), 
				to!(int)(y + get_height()/2));	
			//bottom left
			draw_target_dot(  
				to!(int)(x + get_width()/2), 
				to!(int)(y + get_height()/2 + get_height()));
			//top right
			draw_target_dot(  
				to!(int)(x + get_width()/2 + get_width()), 
				to!(int)(y + get_height()/2));
			//bottom right
			draw_target_dot(  
				to!(int)(x + get_width()/2 + get_width()), 
				to!(int)(y + get_height()/2 + get_height()));
			}

		}

		
	void empty(){}
	}
	
void load_resources()	
	{
	player_anim = new animation_t;
	monster_anim = new animation_t;
	tree_anim = new animation_t;
	jump_anim = new animation_t;
	
	player_anim	.load_extra_frame_mirrored("./data/skier_01.png");
	player_anim	.load_extra_frame_mirrored("./data/skier_02.png");
	player_anim	.load_extra_frame_mirrored("./data/skier_03.png");
	player_anim	.load_extra_frame("./data/skier_04.png");
	player_anim	.load_extra_frame("./data/skier_03.png");
	player_anim	.load_extra_frame("./data/skier_02.png");
	player_anim	.load_extra_frame("./data/skier_01.png");


	monster_anim.load_extra_frame("./data/mysha.pcx");
	tree_anim	.load_extra_frame("./data/tree.png");
	jump_anim	.load_extra_frame("./data/mysha.pcx");
	}

//DEFINITELY want this to be a class / reference type!
class object_t //could we use a drawable_object whereas object_t has re-usable functionality for a camera_t?
	{
	public:
	float 		x, y, z; //objects are centered at X/Y (not top-left) so we can easily follow other objects.
	float		x_vel, y_vel, z_vel; //note Z is used for jumps.

	int direction; // see enum
//	float		angle; // instead of x_vel, y_vel?
//	float		vel;
	float		width, height;
	
	// Collision box. e.g. for trees, it's the stump, not the whole sprite.
	int	bounding_x;
	int	bounding_y;
	int	bounding_w;
	int	bounding_h;

	bool trips_you;
	bool slows_you_down;
	bool is_following_another_object; 
	object_t object_to_follow; 

	this()
		{			
		direction = DIR_DOWN; // -3, -2, -1, 0, 1, 2, 3
		x = 0;
		y = 0;
		z = 0;
		x_vel = 0;
		y_vel = 0;
		z_vel = 0;
		// I thought this shit was AUTO INITALIZED?
			
		trips_you = false;
		slows_you_down = false;
		is_following_another_object = false;
		}
		
	void follow_object(object_t obj)
		{
		is_following_another_object = true;
		object_to_follow = obj;
		}
	
	bool is_colliding_with(object_t obj)
		{
		// I freakin' love D.
		alias x1 = bounding_x;
		alias y1 = bounding_y;
		alias w1 = bounding_w;
		alias h1 = bounding_h;
		
		alias x2 = obj.bounding_x;
		alias y2 = obj.bounding_y;
		alias w2 = obj.bounding_w;
		alias h2 = obj.bounding_h;
		
		/* from https://wiki.allegro.cc/index.php?title=Bounding_Box   GO ALLEGRO GO
		*/
			
		if(	x1 > x2 + w2 - 1 	|| 
			y1 > y2 + h2 - 1 	||
			x2 > x1 + w1 - 1	||
			y2 > y1 + w1 - 1)
			{
			return false;
			}
		return true;
		}
	
	// INPUTS (do we support mouse input?)
	// ------------------------------------------
	void up(){}
	void down(){}
	void left(){}
	void right(){}
	void action(){} // ala space. for monster this would be EAT MWAHAHA. (or is that automatic?) LET HIM EAT OTHER PEOPLE AND STUFF TOO.
	void click_at(float relative_x, float relatie_y){} //maybe? relative to object coordinate.
	
	// EVENTS
	// ------------------------------------------
	void on_tick()
		{
		if(is_following_another_object)
			{
			x = object_to_follow.x;
			y = object_to_follow.y;
			}
		}

	void on_collision(object_t other_obj)
		{
		}	
	}
	
class camera_t : object_t 
	{
	// simply uses the follow object routines in object_t!
	}

class drawable_object_t : object_t
	{
	animation_t animation;
	//int frame; for animated pieces
	//float frame_delay; //number of logic frames per increment 
	//enum direction? // dir=0 for buildings. other directions... how many did skiifree have?
	// this many:
	//  down, 
	//	down left, down left left, left
	//  down right, down right right, right

	void set_animation(animation_t anim)
		{
		assert(anim !is null, "You passed a NULL animation to set_animation in drawable_object_t!");
		animation = anim;
		}

	void draw(viewport_t viewport)
		{		
		alias v = viewport;
		
		//WARNING: CONFIRM THESE.
		if(x + width/2  + width  - v.offset_x < 0)return;	
		if(y + height/2 + height - v.offset_y < 0)return;	
		if(x - width/2           - v.offset_x > SCREEN_W)return;	
		if(y - height/2          - v.offset_y > SCREEN_H)return;	
		
//		al_draw_circle(0, 0, 1, al_map_rgb(0,0,0));
		
		assert(animation !is null, "DID YOU REMEMBER TO SET THE ANIMATION for this object before calling it and blowing it up?");	

		animation.draw_centered(
			direction + 3, //frame, NOTE, hardcoded direction size! 
			x - v.offset_x + v.x, 
			y - v.offset_y + v.y); //clipping not used yet. just pass along the viewport again?
		}
	}
	
class large_tree_t : drawable_object_t
	{
	this()
		{
		direction = DIR_SINGLE_FRAME;
		trips_you = true;
		set_animation(tree_anim); // WARNING, using global interfaced tree_anim

		width = tree_anim.get_width();
		height = tree_anim.get_height();
		}
	}

class small_tree_t : drawable_object_t
	{
	this()
		{
		trips_you = true;
		// TODO
		}
	}

class dead_tree_t : drawable_object_t
	{
	this()
		{
		trips_you = true;
		}
	}

class rock_t : drawable_object_t
	{
	this()
		{
		trips_you = true;
		}
	}

class large_rough_patch_t : drawable_object_t //slows you down.
	{
	this()
		{
		slows_you_down = true;
		}
	}

class small_rough_patch_t : drawable_object_t //slows you down.
	{
	this()
		{
		slows_you_down = true;
		}
	}
	
class sign_t : drawable_object_t
	{
	this()
		{
		trips_you = true;
		}
	}

class lift_stand_t : drawable_object_t //the building
	{
	this()
		{
		trips_you = true;
		}
	}

class lift_chair_t : drawable_object_t
	{
	this()
		{
		}
	}

class tree_stump : drawable_object_t 
	{
	this()
		{
		trips_you = true; //fuck you. ;)
		}
	}

class jump_t : drawable_object_t
	{
	// is a jump bool? OR, an event method!
	// OMG, we could use this method to send ANY OBJECT FLYING, MWAHAHA.
	override void on_collision(object_t other_obj) // I FREAKING LOVE EXPLICIT OVERRIDES.
		{
		alias o = other_obj; //this is kind of cool, we can CLEARLY label the variable, and then use a tiny/ABBREVIATION version.
		//or alias player =
		//or alias p =	
		o.z_vel += JUMP_VELOCITY;
		}
	}

class monster_t : drawable_object_t
	{
	override void on_tick()
		{
		//run torward assholes
		// need a find_player method. (what about multiple players?)
		// Do we also need an A* algorithm (or something more basic) for navigating around objects when stuck?
		// How do we get the monster to zig-zag like in the game?
		}
		
	override void on_collision(object_t other_obj) 
		{
		if(auto p = cast(skier_t) other_obj)
			{
			// I'M GONNA EAT YOU, BUB.
			}		
		}
	}
	
class skier_t : drawable_object_t
	{
	bool is_jumping;
	bool is_grounded;

	this(){}
	this(int x, int y)
		{
		this.x = x; 
		this.y = y;
		
		width  = player_anim.get_width();
		height = player_anim.get_height();
		}
	
	override void up()
			{
			writeln(" - [skier_t] up() recieved.");
			//y_vel -= speed_change_rate;
			//if(y_vel < 0)y_vel = 0;		
			}

	override void down()
			{
			writeln(" - [skier_t] down() recieved.");
			direction=0;
			//y_vel += speed_change_rate;
			//if(y_vel > speed_maximum)y_vel = speed_maximum;		
			}

	override void left()
			{
			writeln(" - [skier_t] left() recieved.");
			direction--;
			if(direction < -3)direction = -3;
			//x_vel -= speed_change_rate;
			//if(x_vel < -speed_maximum)x_vel = -speed_maximum;		
			}

	override void right()
			{
			writeln(" - [skier_t] right() recieved.");
			direction++;
			if(direction > 3)direction = 3;
			//x_vel += speed_change_rate;
			//if(x_vel > speed_maximum)x_vel = speed_maximum;		
			}

	override void action()
			{
			writeln(" - [skier_t] action() recieved.");
			if(is_grounded)
				{
				is_jumping = true; //needed?
				z_vel += player_jump_velocity;
				}
			}

	override void on_tick()
		{
//		writeln("Direction[", direction,"]");
//		x_vel += h_speeds[direction+3];

// FIX ME <-----------

		y_vel += v_speeds[direction+3];
		x_vel += y_vel*v_to_h_conversion[direction+3]*.05;
	
		if(y_vel > 0)y_vel -= 0.01F;
		
		if(x_vel > 0)x_vel -= 0.08F;
		if(x_vel < 0)x_vel += 0.08F;
	
		x += x_vel;
		y += y_vel;
		z += z_vel;
		
		if(x_vel > speed_maximum)x_vel = speed_maximum;
		if(y_vel > speed_maximum)y_vel = speed_maximum;
		if(z_vel > speed_maximum)z_vel = speed_maximum;
		if(x_vel < -speed_maximum)x_vel = -speed_maximum;
		if(y_vel < -speed_maximum)y_vel = -speed_maximum;
		if(z_vel < -speed_maximum)z_vel = -speed_maximum;
		
		if(x < 0){x_vel = 0; x = 0;}
		if(y < 0){y_vel = 0; y = 0;}
		if(z < 0){z_vel = 0; z = 0; is_grounded = true;}
			
		// UPPER BOUNDS
		if(x >= maximum_x){x_vel = 0; x = maximum_x-1;}
		if(y >= maximum_y){y_vel = 0; y = maximum_y-1;}
		if(x >= maximum_z){z_vel = 0; z = maximum_z-1;}
		//writefln("[%f, %f, %f]-v[%f, %f, %f]", x, y, z, x_vel, y_vel, z_vel);
		}
	}
	
class viewport_t
	{
	// Screen coordinates
	int x;
	int y;
	int width;
	int height;
	
	// Camera position
	int offset_x;
	int offset_y;
	}

class world_t
	{
	drawable_object_t [] objects; //should be drawable_object_t?

	ALLEGRO_BITMAP *snow_bmp;

	void draw_background(viewport_t v)
		{
		//texture width/height alias
		int tw = al_get_bitmap_width  (snow_bmp);
		int th = al_get_bitmap_height (snow_bmp);			
		int i = 0;
		int j = 0;
		while(i*tw < v.width*2 + v.offset_x) //is this the RIGHT?
			{
			j=0;
			while(j*th < v.height*2 + v.offset_y) //is this the RIGHT?
				{
				al_draw_bitmap(
					snow_bmp, 
					0 + v.x - v.offset_x - tw/2 + tw*i, 
					0 + v.y - v.offset_y - th/2 + th*j, 
					0);
				stats.number_of_drawn_background_tiles++;
				j++;
				}
			i++;
			}
		}

	// Call this ONCE (or every time new objects appear)
	// Or should we just have different lists for different objects? (so all trees are inherently on a different z-layer from players, etc.)
	void sort_objects_list() //Sorts ALL BUT the first two objects? how?
		{ //easiest way is to simply call before adding the players...
			// or, set the players to the MOST negative Y position until after sorting.
			// WE COULD EVEN STORE THE VALUES TEMPORARILY!
		// WARNING: ASsumes players 1 and 2 EXIST and are first already.
		float temp_p0_y = objects[0].y;
		float temp_p1_y = objects[1].y;
		objects[0].y = -1000;
		objects[1].y =  -900;
		
		alias comparison = (o1, o2) => o1.y < o2.y; //should be ordered ascending, ala [1,2,3,4]
		
		objects.sort!(comparison); //COULD THIS BREAK in a way we don't anticipate?
		// as long as trees are AFTER these objects, and 
		
		objects[0].y = temp_p0_y;
		objects[1].y = temp_p1_y;		
		}

	void populate_with_trees()
		{
		immutable int number_of_trees = 1000;
		
		for(int i = 0; i < number_of_trees; i++)
			{
			large_tree_t tree = new large_tree_t;
			tree.x = uniform(0, maximum_x);
			tree.y = uniform(0, maximum_y);
		
			objects ~= tree;
			}
		}
 	
	void draw(viewport_t viewport)
		{
		draw_background(viewport);
		foreach(o; objects)
			{
			o.draw(viewport);
			}
		}

	void logic()
		{
		foreach(o; objects)
			{
			o.on_tick();
			}
		}
	
	void test()
		{
		skier_t x;
		objects ~= x; //polymorphism rules. 
		}
	}

//https://www.allegro.cc/manual/5/keyboard.html
//	(instead of individual KEYS touching ANY OBJECT METHOD. Because what if we 
// 		change objects? We have to FIND all keys associated with that object and 
// 		change them.)
alias ALLEGRO_KEY = ubyte;
struct keyset_t
		{
		object_t obj;
		ALLEGRO_KEY [5] key;
		// If we support MOUSE clicks, we could simply attach a MOUSE in here 
		// and have it forward to the object's click_on() method.
		// But again, that kills the idea of multiplayer.
		}
		
enum
	{
	UP_KEY = 0,
	DOWN_KEY = 1,
	LEFT_KEY = 2,
	RIGHT_KEY = 3,
	ACTION_KEY = 4
	}

bool initialize()
	{
	if (!al_init())
		{
		auto ver 		= al_get_allegro_version();
		auto major 		= ver >> 24;
		auto minor 		= (ver >> 16) & 255;
		auto revision 	= (ver >> 8) & 255;
		auto release 	= ver & 255;

		writefln("The system Allegro version (%s.%s.%s.%s) does not match the version of this binding (%s.%s.%s.%s)",
			major, minor, revision, release,
			ALLEGRO_VERSION, ALLEGRO_SUB_VERSION, ALLEGRO_WIP_VERSION, ALLEGRO_RELEASE_NUMBER);

		assert(0, "The system Allegro version does not match the version of this binding!"); //why didn't they do this as an assert to begin with?
		}
/*	
	what was this supposed to be used for??
	
	cfg = al_load_config_file("test.ini"); // THIS ISN'T HERE, is it?
	if (cfg == null)
		{
		assert(0, "OMG WHERE CONFIG FILE.");
		}
	*/
	
static if (false) // MULTISAMPLING. Not sure if helpful.
	{
	with (ALLEGRO_DISPLAY_OPTIONS)
		{
		al_set_new_display_option(ALLEGRO_SAMPLE_BUFFERS, 1, ALLEGRO_REQUIRE);
		al_set_new_display_option(ALLEGRO_SAMPLES, 8, ALLEGRO_REQUIRE);
		}
	}

	al_display = al_create_display(SCREEN_W, SCREEN_H);
	queue	= al_create_event_queue();

	if (!al_install_keyboard())      assert(0, "al_install_keyboard failed!");
	if (!al_install_mouse())         assert(0, "al_install_mouse failed!");
	if (!al_init_image_addon())      assert(0, "al_init_image_addon failed!");
	if (!al_init_font_addon())       assert(0, "al_init_font_addon failed!");
	if (!al_init_ttf_addon())        assert(0, "al_init_ttf_addon failed!");
	if (!al_init_primitives_addon()) assert(0, "al_init_primitives_addon failed!");

	al_register_event_source(queue, al_get_display_event_source(al_display));
	al_register_event_source(queue, al_get_keyboard_event_source());
	al_register_event_source(queue, al_get_mouse_event_source());
	
	bmp 		= al_load_bitmap("./data/mysha.pcx");
	font = al_load_font("./data/DejaVuSans.ttf", 18, 0);

	with(ALLEGRO_BLEND_MODE)
		{
		al_set_blender(ALLEGRO_BLEND_OPERATIONS.ALLEGRO_ADD, ALLEGRO_ALPHA, ALLEGRO_INVERSE_ALPHA);
		}

	color1 = al_color_hsl(0, 0, 0);
	color2 = al_map_rgba_f(0.5, 0.25, 0.125, 1);
	writefln("%s, %s, %s, %s", color1.r, color1.g, color2.b, color2.a);
	
	// load animations/etc
	// --------------------------------------------------------
	load_resources();

	// SETUP world
	// --------------------------------------------------------
	world = new world_t;
	world.snow_bmp 	= al_load_bitmap("./data/snow.jpg");

	// Create objects for player's 1 and 2 as first two slots
	// --------------------------------------------------------
	skier_t player1 = new skier_t( 50, 50);
	skier_t player2 = new skier_t(200, 50);

	player1.set_animation(player_anim);	
	player2.set_animation(player_anim);
	
	world.objects ~= player1; //should be [0]
	world.objects ~= player2; //should be [1]
	
	// Create other objects.
	// --------------------------------------------------------

	world.populate_with_trees();

	// SETUP player controls
	// --------------------------------------------------------
	player_controls[0].key[UP_KEY	] = ALLEGRO_KEY_UP;
	player_controls[0].key[DOWN_KEY	] = ALLEGRO_KEY_DOWN;
	player_controls[0].key[LEFT_KEY	] = ALLEGRO_KEY_LEFT;
	player_controls[0].key[RIGHT_KEY] = ALLEGRO_KEY_RIGHT;
	player_controls[0].key[ACTION_KEY] = ALLEGRO_KEY_SPACE;
	player_controls[0].obj = world.objects[0];
	
	player_controls[1].key[UP_KEY	] = ALLEGRO_KEY_W;
	player_controls[1].key[DOWN_KEY	] = ALLEGRO_KEY_S;
	player_controls[1].key[LEFT_KEY	] = ALLEGRO_KEY_A;
	player_controls[1].key[RIGHT_KEY] = ALLEGRO_KEY_D;
	player_controls[1].key[ACTION_KEY] = ALLEGRO_KEY_R;
	player_controls[1].obj = world.objects[1];

	// SETUP viewports
	// --------------------------------------------------------
	viewports[0] = new viewport_t;
	viewports[0].x = 0;
	viewports[0].y = 0;
	viewports[0].width  = SCREEN_W/2;// - 1;
	viewports[0].height = SCREEN_H;
	viewports[0].offset_x = 0;
	viewports[0].offset_y = 0;

	viewports[1] = new viewport_t;
	viewports[1].x = SCREEN_W/2;
	viewports[1].y = 0;
	viewports[1].width  = SCREEN_W/2;//[ - 1;
	viewports[1].height = SCREEN_H;
	viewports[1].offset_x = 0;
	viewports[1].offset_y = 0;

	assert(viewports[0] !is null);
	
	// Finish object setup
	// --------------------------------------------------------
	
	world.sort_objects_list(); //sort trees z-ordering above players, and higher trees behind lower trees. (drawn first.) 
	target.x = 590;
	target.y = 300;

	// FPS
	// --------------------------------------------------------
	fps_timer = al_create_timer(1.0f);
	al_register_event_source(queue, al_get_timer_event_source(fps_timer));
	al_start_timer(fps_timer);
	
	return 0;
	}

	
struct display_t
	{
	void start_frame()	
		{
		stats.number_of_drawn_objects=0;
		stats.number_of_drawn_background_tiles=0;
		display.reset_clipping();
		al_clear_to_color(ALLEGRO_COLOR(1,0,0, 1));
		}
		
	void end_frame()
		{	
		al_flip_display();
		}

	void draw_frame()
		{
		start_frame();
		//------------------

		draw2();

		//------------------
		end_frame();
		}

	void reset_clipping()
		{
		al_set_clipping_rectangle(0,0, SCREEN_W-1, SCREEN_H-1);
		}
		
	void draw2()
		{
		
	static if(true) //draw left viewport
		{
		al_set_clipping_rectangle(
			viewports[0].x, 
			viewports[0].y, 
			viewports[0].x + viewports[0].width ,  //-1
			viewports[0].y + viewports[0].height); //-1
		al_clear_to_color(ALLEGRO_COLOR(1,1,1, 1));
		world.draw(viewports[0]);
		}

	static if(true) //draw right viewport
		{
		al_set_clipping_rectangle(
			viewports[1].x, 
			viewports[1].y, 
			viewports[1].x + viewports[1].width  - 1, 
			viewports[1].y + viewports[1].height - 1);
		al_clear_to_color(ALLEGRO_COLOR(.8,.8,.8, 1));
		world.draw(viewports[1]);
		}
		
		//Viewport separator
	static if(true)
		{
		al_draw_line(
			SCREEN_W/2 + 0.5, 
			0 + 0.5, 
			SCREEN_W/2 + 0.5, 
			SCREEN_H + 0.5,
			al_map_rgb(0,0,0), 
			10);
		}
		
		// Draw FPS and other text
		display.reset_clipping();
			al_draw_textf(font, ALLEGRO_COLOR(0, 0, 0, 1), 20, text_helper(false), ALLEGRO_ALIGN_LEFT, "fps[%d]", stats.fps);
			al_draw_textf(font, ALLEGRO_COLOR(0, 0, 0, 1), 20, text_helper(false), ALLEGRO_ALIGN_LEFT, "mouse [%d, %d]", mouse_x, mouse_y);
			al_draw_textf(font, ALLEGRO_COLOR(0, 0, 0, 1), 20, text_helper(false), ALLEGRO_ALIGN_LEFT, "target [%d, %d]", target.x, target.y);
			al_draw_textf(font, ALLEGRO_COLOR(0, 0, 0, 1), 20, text_helper(false), ALLEGRO_ALIGN_LEFT, "number of drawn objects [%d], tiles [%d]", stats.number_of_drawn_objects, stats.number_of_drawn_background_tiles);
			
			al_draw_textf(font, ALLEGRO_COLOR(0, 0, 0, 1), 20, text_helper(false), ALLEGRO_ALIGN_LEFT, "player1.xy [%2.2f/%2.2f] v[%2.2f/%2.2f] d[%d]", world.objects[0].x, world.objects[0].y, world.objects[0].x_vel, world.objects[0].y_vel, world.objects[0].direction);
			al_draw_textf(font, ALLEGRO_COLOR(0, 0, 0, 1), 20, text_helper(false), ALLEGRO_ALIGN_LEFT, "player2.xy [%2.2f/%2.2f] v[%2.2f/%2.2f] d[%d]", world.objects[1].x, world.objects[1].y, world.objects[1].x_vel, world.objects[1].y_vel, world.objects[1].direction);
		text_helper(true);  //reset
		
		// DRAW MOUSE PIXEL HELPER/FINDER
		draw_target_dot(mouse_x, mouse_y);
		draw_target_dot(target.x, target.y);
		al_draw_textf(font, ALLEGRO_COLOR(0, 0, 0, 1), mouse_x, mouse_y - 30, ALLEGRO_ALIGN_CENTER, "mouse [%d, %d]", mouse_x, mouse_y);
		}

	}

void draw_target_dot(int x, int y)
	{
	al_draw_pixel(x + 0.5, y + 0.5, al_map_rgb(0,1,0));

	immutable r = 2; //radius
	al_draw_rectangle(x - r + 0.5f, y - r + 0.5f, x + r + 0.5f, y + r + 0.5f, al_map_rgb(0,1,0), 1);
	}

/// For each call, this increments and returns a new Y coordinate for lower text.
int text_helper(bool do_reset)
	{
	static int number_of_entries = -1;
	
	number_of_entries++;
	immutable int text_height = 20;
	immutable int starting_height = 20;
	
	if(do_reset)number_of_entries = 0;
	
	return starting_height + text_height*number_of_entries;
	}

void calculate_camera()
	{
	// Calculate camera
	viewports[0].offset_x = to!(int)(world.objects[0].x)-(viewports[0].width/2);
	viewports[0].offset_y = to!(int)(world.objects[0].y)-(viewports[0].height/2);

	viewports[1].offset_x = to!(int)(world.objects[1].x)-(viewports[1].width/2);
	viewports[1].offset_y = to!(int)(world.objects[1].y)-(viewports[1].height/2);
	}

void logic()
	{
	calculate_camera();
	world.logic();
	}

void execute()
	{
	bool exit = false;
	while(!exit)
		{
		ALLEGRO_EVENT event;
		while(al_get_next_event(queue, &event))
			{
			switch(event.type)
				{
				case ALLEGRO_EVENT_DISPLAY_CLOSE:
					{
					exit = true;
					break;
					}
				case ALLEGRO_EVENT_KEY_DOWN:
					{
					if(event.keyboard.keycode == ALLEGRO_KEY_I)
						{
						target.y--;
						}
					if(event.keyboard.keycode == ALLEGRO_KEY_K)
						{
						target.y++;
						}
					if(event.keyboard.keycode == ALLEGRO_KEY_J)
						{
						target.x--;
						}
					if(event.keyboard.keycode == ALLEGRO_KEY_L)
						{
						target.x++;
						}

					foreach(int i, keyset_t player_data; player_controls)
						{
						if(event.keyboard.keycode == player_data.key[UP_KEY])
							{
							writefln("Player %d - UP", i+1);
							player_data.obj.up();
							}
						if(event.keyboard.keycode == player_data.key[DOWN_KEY])
							{
							writefln("Player %d - DOWN", i+1);
							player_data.obj.down();
							}
						if(event.keyboard.keycode == player_data.key[LEFT_KEY])
							{
							writefln("Player %d - LEFT", i+1);
							player_data.obj.left();
							}
						if(event.keyboard.keycode == player_data.key[RIGHT_KEY])
							{
							writefln("Player %d - RIGHT", i+1);
							player_data.obj.right();
							}
						if(event.keyboard.keycode == player_data.key[ACTION_KEY])
							{
							writefln("Player %d - ACTION", i+1);
							player_data.obj.action();
							}
						}
							
					switch(event.keyboard.keycode)
						{					
						case ALLEGRO_KEY_ESCAPE:
							{
							exit = true;
							break;
							}
						default:
						}
						break;
					
					}
					
				case ALLEGRO_EVENT_MOUSE_AXES:
					{
					mouse_x = event.mouse.x;
					mouse_y = event.mouse.y;
					break;
					}

				case ALLEGRO_EVENT_MOUSE_BUTTON_DOWN:
					{
				//	exit = true;
					break;
					}
				
				case ALLEGRO_EVENT_TIMER:
					{
					if(event.timer.source == fps_timer)
						{
						
						stats.fps = stats.frames_passed;
						stats.frames_passed = 0;
						}
					break;
					}
				
				default:
			}
		}

		logic();
		display.draw_frame();
		stats.frames_passed++;
		}
	}

//best name? shutdown()? used. exit()? used. free? used. close()? used. finalize()? ???   --- Applicable name?
// Finalize? Destroy? Terminate? Kill? Cleanup? Uninitialize? Deinitialize?  
// >Dispose?
void terminate() //I think "shutdown" is a standard lib UNIX function. Easier for breakpointing by name.
	{
		
	}

//=============================================================================
int main(string [] args)
	{
	writeln("args length = ", args.length);
	foreach(int i, string arg; args)
		{
		writeln("[",i, "] ", arg);
		}
		
	if(args.length > 2)
		{
		SCREEN_W = to!int(args[1]);
		SCREEN_H = to!int(args[2]);
		writeln("New resolution is ", SCREEN_W, "x", SCREEN_H);
		}


	return al_run_allegro(
		{
		initialize();
		execute();
		terminate();
		return 0;
		} );
	}
