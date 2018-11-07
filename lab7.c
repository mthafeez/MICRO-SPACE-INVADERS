// dmrichwa & mthafeez

#include <stdlib.h>

extern int lab7(void);

extern void status_RGB(void);

extern void output_string_c(char* base);
extern char* num_to_ascii_c(int num);

// init
void start_game(char* base_GAMESTATUS, char* base_MISC, char* base_RNG, char* base_LIVES);
void mothership(char* base_SCORE, char* base_address_SCORE_TOTAL, char* base_BULLETS_P, char* base_BULLETS_E);

// helper
void clock_convert(char* game_clock, char* clock_string);
void update_RNG(void);
void enemy_shoot(char* enemyChar, int enemyRow, int enemyCol, int enemyPos);
void update_score(void);

// main
void handle_inputs(char* base_input, char* base_input_flags);
void kill_player(char* flag_DEATH_COUNT, char* flag_PLAYER_ANIMATION, char* boardChar, int playerPos);
void update_board(char* base_cur, char* base_new, char* base_input_flags);

/*
|---------------------|
|                     |
|       OOOOOOO       |
|       MMMMMMM       |
|       MMMMMMM       |
|       WWWWWWW       |
|       WWWWWWW       |
|                     |
|                     |
|                     |
|                     |
|                     |
|   SSS   SSS   SSS   |
|   S S   S S   S S   |
|                     |
|          A          |
|---------------------|
	
|---------------------||                     ||       OOOOOOO       ||       MMMMMMM       ||       MMMMMMM       ||       WWWWWWW       ||       WWWWWWW       ||                     ||                     ||                     ||                     ||                     ||   SSS   SSS   SSS   ||   S S   S S   S S   ||                     ||          A          ||---------------------|

Code to print to PuTTy:

output_string_c("\033[34;34H[RNG: ");
output_string_c(num_to_ascii_c(RNG & 7));
output_string_c("]");
*/

int main()
{
	lab7();
	return 0;
}

// variables to update memory
char* address_BULLETS_P;
char* address_BULLETS_E;
char* address_GAMESTATUS;
char* address_LIVES;
char* address_MISC;
char* address_RNG;
char* address_SCORE;
char* address_SCORE_TOTAL;

// interim variables
int score_update = 0;		// score to add at the end
int score_MOTHERSHIP;		// number of points killing the mothership will give
int RNG;					// current RNG number
int boardSum = 0;			// sum of ASCII values of board (used in RNG)

void start_game(char* base_GAMESTATUS, char* base_MISC, char* base_RNG, char* base_LIVES)
{
	// load in global variable memory locations
	address_GAMESTATUS = base_GAMESTATUS;
	address_MISC = base_MISC;
	address_RNG = base_RNG;
	address_LIVES = base_LIVES;
	
	// set bottom row to 6 (default bottom row)
	char* flag_ENEMY_BOTTOM = address_MISC + 9; // byte 9: bottom enemy row (1-something)
	*flag_ENEMY_BOTTOM = 6;
	
	// update RNG
	update_RNG();
	
	if (RNG % 1 == 0)	*address_MISC = 0;	// enemies start moving left
	else				*address_MISC = 1;	// enemies start moving right
	
	*(address_MISC + 13) = 1; // flush out inputs at the start of the game
}

void mothership(char* base_SCORE, char* base_SCORE_TOTAL, char* base_BULLETS_P, char* base_BULLETS_E)
{
	// pass in address global variables
  	address_SCORE = base_SCORE;
  	address_SCORE_TOTAL = base_SCORE_TOTAL;
	address_BULLETS_P = base_BULLETS_P;
	address_BULLETS_E = base_BULLETS_E;
	
	if (*(address_MISC + 10) % 30 != 0)	return;			// do not try to spawn faster than normal game rate
	
	int isSpawned = *(address_MISC + 2) & 1;			// grab the byte telling us whether a mothership is currently spawning or is already spawned
	
	if (isSpawned == 0 && *(address_MISC + 16) == 0)	// if that byte is 0 and we're not in an animation, that means we are safe to try to spawn
	{
		if ((RNG & 7) == 1)								// check if RNG bits 2:0 are b001
		{
			*(address_MISC + 2) = 1;					// if the bit is 1 then spawn the mothership
		}
		if ((RNG & 15) >= 6)							// check if RNG bits 3:0 are 6 or greater
		{
			*(address_MISC + 1) = 0;					// set mothership direction bit to 0 (left)
		}
		else
		{
			*(address_MISC + 1) = 1;					// set mothership direction bit to 1 (right)
		}
		if (RNG >= 170)		score_MOTHERSHIP = 300;
		else if(RNG >= 85)	score_MOTHERSHIP = 100;
		else				score_MOTHERSHIP = 200;
	}
}

void clock_convert(char* game_clock, char* clock_string)
{
	int timer = *game_clock & 255;
	int temp1 = *(game_clock+1) & 255;
	
	timer = timer << 8;
	timer = timer + temp1;
	timer = timer / 200;
	
	*(clock_string) = timer;
}

void update_RNG()
{
	RNG = *address_RNG; // update RNG variable
	srand(boardSum);
	int rnum = rand() % 63;
	RNG += rnum;
	if (RNG > 255) RNG = RNG - 255; // wrap around
  	*address_RNG = RNG; // update global RNG
}

void enemy_shoot(char* enemyChar, int enemyRow, int enemyCol, int enemyPos)
{
	char* flag_ENEMY_BOTTOM = address_MISC + 9; // byte 9: bottom enemy row (1-something)
	// this causes a bullet to be spawned at the enemy's position at time of sending to function, if RNG check passes
	// only the bottom row of enemies may shoot
	// do not shoot if there's something blocking the row below the enemy
	if (enemyRow == *flag_ENEMY_BOTTOM && (RNG % 7) == 0 && *(enemyChar + 23) == ' ')
	{
		*(enemyChar + 23) = 'V';	// special "just spawned" character
		*(address_BULLETS_E + enemyPos + 23) = 'V';
	}
  	update_RNG();
}

void handle_inputs(char* base_input, char* base_input_flags)
{
	char leftRight = ' ';
	char didSpace = '0';
	int cont = 1;
	while (cont == 1) // iterate through the string until we reach the NULL character
	{
		// look at last A/D to determine whether to move player left or right
		if (*base_input == 'a' || *base_input == 'A' || *base_input == 'd' || *base_input == 'D')
		{
			leftRight = *base_input; // update left or right flag to the latest aAdD key the user hit
		}
		// check if they hit space to see if they should shoot
		if (*base_input == ' ')
		{
			didSpace = '1'; // update flag to say the user did hit space
		}
		base_input++;
		if (*base_input == 0) cont = 0; // when we reach NULL character, stop the loop
	}
	*base_input_flags = leftRight;			// byte 0: last left/right movement input
	*(base_input_flags + 1) = didSpace;		// byte 1: did user hit space to shoot
}

void update_score()
{	
	// update level score
	int levelUpper = *address_SCORE;					// get the current level score
	int levelLower = *(address_SCORE + 1);
	int levelScore = levelLower + (levelUpper << 8); 	// add upper shifted left 8 places plus lower
	
	levelScore += score_update;							// add new score
	
	int upperScore = (levelScore & 0xFF00) >> 8;		// isolate upper byte and shift right 8 places
	int lowerScore = levelScore & 0xFF;					// isolate lower byte
	
	*address_SCORE = upperScore;						// store back into memory
	*(address_SCORE + 1) = lowerScore;
	
	// update game score
	int gameUpper = *address_SCORE_TOTAL;				// get the current game score
	int gameLower = *(address_SCORE_TOTAL + 1);
	int gameScore = gameLower + (gameUpper << 8);		// add upper shifted left 8 places plus lower
	
	gameScore += score_update;							// add new score
	
	upperScore = (gameScore & 0xFF00) >> 8;				// isolate upper byte and shift right 8 places
	lowerScore = gameScore & 0xFF;						// isolate lower byte
	*address_SCORE_TOTAL = upperScore;					// store back into memory
	*(address_SCORE_TOTAL + 1) = lowerScore;
}

void kill_player(char* flag_DEATH_COUNT, char* flag_PLAYER_ANIMATION, char* boardChar, int playerPos)
{
	if (*flag_PLAYER_ANIMATION > 0) return;	// player is invincible while animating
	score_update -= 100;	// decrement 100 points for dying
	*flag_DEATH_COUNT = *flag_DEATH_COUNT + 1;	// increase death count
	*flag_PLAYER_ANIMATION = 1; // start death animation
	*(address_MISC + 19) = playerPos;	// update player death position animation
	if (*address_LIVES == 15)	*address_LIVES = 7;	// 15 = b1111 = 4 lives --> 7 = b0111 = 3 lives
	else if (*address_LIVES == 7)	*address_LIVES = 3;
	else if (*address_LIVES == 3)	*address_LIVES = 1;
	else if (*address_LIVES == 1)	// ran out of lives -- game over
	{
		*address_LIVES = 0;
		*address_GAMESTATUS = 3;	// set game status to 3 (game over)
		status_RGB();
	}
	*(boardChar + 23) = ' ';	// kill player
}

void update_board(char* base_cur, char* base_new, char* base_input_flags)
{
	//---Variables---//
	char* flag_LEFTRIGHT = base_input_flags;		// byte 0: last left/right movement input
	char* flag_SPACE = base_input_flags + 1;		// byte 1: did user hit space to shoot
	char* flag_MISC = address_MISC;				// many miscellaneous flags
		char* flag_ENEMY_LEFTRIGHT = flag_MISC; // byte 0: enemies moving left/right (0 = left, 1 = right)
		char* flag_MOTHER_DIRECTION = flag_MISC + 1; // byte 1: mothership moving left/right (0 = left, 1 = right)
		char* flag_MOTHER_SPAWN = flag_MISC + 2; // byte 2: mothership needs to spawn or is currently spawned? (0 = no, 1 = yes)
		char* flag_LEVEL = flag_MISC + 3; // byte 3: level flag (level 0 = menu or game over; max 2^8 - 1 = 255)
		char* flag_MOTHER_COUNT_LEVEL = flag_MISC + 4; // byte 4: how many motherships spawned in this level (max 255)
		char* flag_MOTHER_KILL_LEVEL = flag_MISC + 5; // byte 5: how many motherships were killed in this level (max 255)
		char* flag_DEATH_COUNT = flag_MISC + 6; // byte 6: death count in this level (max 255)
		char* flag_MOTHER_COUNT_GAME = flag_MISC + 7; // byte 7: how many motherships spawned this game (max 255)
		char* flag_MOTHER_KILL_GAME = flag_MISC + 8; // byte 8: how many motherships were killed this game (max 255)/
		char* flag_ENEMY_BOTTOM = flag_MISC + 9; // byte 9: bottom enemy row (1-something)
		char* flag_TIMER_COUNTER = flag_MISC + 10; // byte 10: timer0 counter (0-59)
		char* flag_ENEMY_DOWN = flag_MISC + 11;	// byte 11: did we move enemies down last tick? (0 = no, 1 = yes)
		char* flag_SHOOT_ANIMATION = flag_MISC + 12; // byte 12: RGB LED counter (flashing when shooting) (0 = no, 1 = just shot, 2+ = in middle of animation)
		char* flag_FLUSH_INPUTS = flag_MISC + 13; // byte 13: flush inputs? (0 = no, 1 = yes)
		char* flag_PLAYER_ANIMATION = flag_MISC + 14; // byte 14: player death animation counter (0 = unused, 1 = start, 2+ = in middle)
		char* flag_MOTHER_ANIMATION = flag_MISC + 16; // byte 16: mothership kill animation counter (0 = unused, 1 = start, 2+ = in motion)
		char* flag_MOTHER_POSITION = flag_MISC + 17; // byte 17: mothership kill animation position (column)
		char* flag_MOTHER_SCORE = flag_MISC + 18; // byte 18: stored mothership score
		char* flag_PLAYER_POSITION = flag_MISC + 19; // byte 19: player death animation position (column)
	
	int newBottomRow = -1;		// interim bottom row of enemies (to update cached bottom row)
	int enemyMoveDown = 0;		// should we move the line of enemies down?
	int enemyAgainstLeft = 0;	// enemy against left wall
	int enemyAgainstRight = 0;	// enemy against right wall
	int motherAgainstLeft = 0;	// mothership against left wall
	int motherAgainstRight = 0; // mothership against right wall
	int mothershipPresent = 0;	// does a mothership currently exist?
	int enemiesPresent = 0;		// do any enemies currently exist?
	int didFlush = 0;			// did we flush inputs?
	
	int timerDivisor = 1;		// divisor of timer counter based on level
													// 1x		1.5x	2x		3x
	if (*flag_LEVEL == 1)		timerDivisor = 30;	// 0.5s		0.333s	0.25s	0.167s
	else if (*flag_LEVEL == 2)	timerDivisor = 24;	// 0.4s		0.267s	0.2s	0.133s
	else if (*flag_LEVEL == 3)	timerDivisor = 18;	// 0.3s		0.2s 	0.15s	0.1s
	else if (*flag_LEVEL == 4)	timerDivisor = 12;	// 0.2s		0.133s	0.1s	0.067s
	else						timerDivisor = 6;	// 0.1s		0.067s	0.05s	0.033s
	
	int tick = *flag_TIMER_COUNTER % timerDivisor;
	int tick_onepointfive = *flag_TIMER_COUNTER % ((timerDivisor * 10) / 15); // buggy; do not use
	int tick_two = *flag_TIMER_COUNTER % (timerDivisor / 2);
	int tick_three = *flag_TIMER_COUNTER % (timerDivisor / 3);
	
	score_update = 0;	// reset the amount of score to add
	//---/Variables---//
	
	//---Settings---//
	int enemySpeed = tick;
	int motherSpeed = tick_two;
	int playerSpeed = tick_three;
	int bulletSpeed = tick_three;
	//---/Settings---//
	
	//---Initialization---//
	update_RNG();	// update RNG
	
	// check to see if enemies and/or mothership are against a wall by looking down the left and right columns
	for (int i = 1; i <= 15; i++) // row
	{
		int cellLeftPos = i*23 + 1; // leftmost column
		int cellRightPos = i*23 + 21; // rightmost column
		char* cellLeft = base_new + cellLeftPos;
		char* cellRight = base_new + cellRightPos;
		// if there's an enemy/mothership in these columns they are against a wall
		if (*cellLeft == 'O' || *cellLeft == 'M' || *cellLeft == 'W')		enemyAgainstLeft = 1;
		if (*cellLeft == 'X')												motherAgainstLeft = 1;
		if (*cellRight == 'O' || *cellRight == 'M' || *cellRight == 'W')	enemyAgainstRight = 1;
		if (*cellRight == 'X')												motherAgainstRight = 1;
	}
	
	// check to see if a mothership is currently present by looking at the top row
	for (int j = 1; j <= 21; j++) // column
	{
		int cellPos = 1*23 + j; // position in string is row*width + column
		char* cell = base_new + cellPos;
		if (*cell == 'X') mothershipPresent = 1;	// if we spot an 'X' that means there's a mothership present
	}
	
	//---Animations---//
	// player respawn
	if (*flag_PLAYER_ANIMATION > 0)
	{
		if (*flag_PLAYER_ANIMATION < 30)
		{
			int position = *flag_PLAYER_POSITION;
			if (position > 18) position = 18;	// do not overflow score over board
			position += 4; // offset into game board
			
			// move cursor 
			output_string_c("\033[19;");
			output_string_c(num_to_ascii_c(position));
			output_string_c("H");
			
			// output text
			if (*flag_PLAYER_ANIMATION % 10 == 0)	output_string_c("-100");
			else if (*flag_PLAYER_ANIMATION % 10 == 5) output_string_c("    ");
		}
		else
		{
			if (*flag_PLAYER_ANIMATION % 10 == 0) // flash the player off
			{
				*(base_new + 15*23 + 11) = ' ';
			}
			else if (*flag_PLAYER_ANIMATION % 10 == 5) // flash the player on
			{
				*(base_new + 15*23 + 11) = 'A';
			}
		}
		
		// go to the next frame of animation
		*flag_PLAYER_ANIMATION = *flag_PLAYER_ANIMATION + 1;
		if (*flag_PLAYER_ANIMATION == 60) *flag_PLAYER_ANIMATION = 0;
	}
	
	// mothership killed
	if (*flag_MOTHER_ANIMATION > 0)
	{
		int position = *flag_MOTHER_POSITION;
		if (position > 19) position = 19;	// do not overflow score over board
		position += 4; // offset into game board

		int score = *flag_MOTHER_SCORE * 10; // actual score is 10 times the stored score
		
		// move cursor 
		output_string_c("\033[5;");
		output_string_c(num_to_ascii_c(position));
		output_string_c("H");
		
		// output text
		if (*flag_MOTHER_ANIMATION % 15 == 0)	output_string_c(num_to_ascii_c(score));
		else if (*flag_MOTHER_ANIMATION % 15 == 8) output_string_c("   ");
		
		// go to next frame of animation
		*flag_MOTHER_ANIMATION = *flag_MOTHER_ANIMATION + 1;
		if (*flag_MOTHER_ANIMATION == 60) *flag_MOTHER_ANIMATION = 0;	// done with animation
	}
	//---Animations---//
	//---Initialization---//
	
	//---Main Loop---//
	// use this loop to move things UP or LEFT
	for (int i = 1; i <= 15; i++) // row
	{
		for (int j = 1; j <= 21; j++) // column
		{
			int cellPos = i*23 + j; // position in string is row*width + column
			char* cell = base_new + cellPos;
			
			boardSum += (int)*cell * cellPos;	// convert each position in string to ASCII
			
			if (*cell == 'A' && playerSpeed == 0 && *flag_PLAYER_ANIMATION == 0)	// player
			{
				// flush out inputs
				*flag_FLUSH_INPUTS = 1;
				didFlush = 1;
				
				// if user hit left, move player left; do not move into wall
				if ((*flag_LEFTRIGHT == 'a' || *flag_LEFTRIGHT == 'A') && j > 1)
				{
					*(cell - 1) = *cell;	// move player left
					*cell = ' ';
				}
				
				// find the newest bullet
				int newestBullet = -1;
				int bulletPos = 0;
				char* bulletChar = address_BULLETS_P;
				while (*(bulletChar + bulletPos) != '\0')
				{
					if (*(bulletChar + bulletPos) != '^' && *(bulletChar + bulletPos) != '&' && *(bulletChar + bulletPos) != '~')	// ignore non-player bullets
					{
						bulletPos++;
						continue;
					}
					if (bulletPos > newestBullet) newestBullet = bulletPos;	// we found a newer bullet
					bulletPos++;	// go to the next position
				}
				
				// if user hit space, shoot, but only if newest bullet is at least 5 rows above us and there's nothing above us
				if (*flag_SPACE == '1' && newestBullet < (15 - 4)*23 + j && *(cell - 23) == ' ')
				{
					*(cell - 23) = '&';	// spawn a bullet above player
					*flag_SPACE = '0';	// disable shooting multiple times in one tick
					*(address_BULLETS_P + cellPos - 23) = '&';	// update bullet string
					*flag_SHOOT_ANIMATION = 1;	// start the shooting animation
				}
			}
			if (*cell == 'O' || *cell == 'M' || *cell == 'W') // enemies
			{
				enemiesPresent = 1; // we found an enemy
				if (i > newBottomRow) newBottomRow = i;	// update new bottom row
				if (*flag_ENEMY_LEFTRIGHT == 0 && enemySpeed == 0)	// moving left
				{
					if (enemyAgainstLeft)	// if we're against a wall, change directions
					{
						*flag_ENEMY_LEFTRIGHT = 1;	// set direction to 1 (right)
						enemyMoveDown = 1;
					}
					else
					{
						// game over when enemies hit shields
						if (*(cell - 1) == 'S' || *(cell - 1) == 's')
						{
							*address_GAMESTATUS = 3;	// set game status to game over
							status_RGB();
						}
						*(cell - 1) = *cell; // move enemy left
						*cell = ' ';
						enemy_shoot(cell - 1, i, j, cellPos - 1); // shoot at new enemy position and current row
					}
				}
			}
			if (*cell == 'X') // mothership
			{
				if (*flag_MOTHER_DIRECTION == 0 && motherSpeed == 0) // moving left
				{
					if (motherAgainstLeft)	*flag_MOTHER_SPAWN = 0;	// we missed the ship
					else					*(cell - 1) = *cell;	// move the mothership over
					*cell = ' ';	// delete current position
				}
			}
		}
	}
	
	// use this loop to move things DOWN or RIGHT
	int switchDirections = 0;
	for (int i = 15; i >= 1; i--) // row
	{
		for (int j = 21; j >= 1; j--) // column
		{
			int cellPos = i*23 + j; // position in string is row*width + column
			char* cell = base_new + cellPos;
			
			if (*cell == 'A' && playerSpeed == 0 && *flag_PLAYER_ANIMATION == 0)	// player
			{
				// flush out inputs
				*flag_FLUSH_INPUTS = 1;
				didFlush = 1;
				
				// if user hit right, move player right; do not move into wall
				if ((*flag_LEFTRIGHT == 'd' || *flag_LEFTRIGHT == 'D') && j < 21)
				{
					*(cell + 1) = *cell;	// move player right
					*cell = ' ';
				}
			}
			if (*cell == 'O' || *cell == 'M' || *cell == 'W') // enemies
			{
				enemiesPresent = 1; // we found an enemy
				if (*flag_ENEMY_LEFTRIGHT == 1 && enemySpeed == 0) // enemies moving to the right
				{
					if (enemyAgainstRight)	// if we're against a wall, change directions
					{
						switchDirections = 1;
						enemyMoveDown = 1;
					}
					if (enemyMoveDown && *flag_ENEMY_DOWN == 0)	// do not move down enemies multiple times -- compare cached value
					{
						// game over when enemies hit shields
						if (*(cell + 23) == 'S' || *(cell + 23) == 's')
						{
							*address_GAMESTATUS = 3;	// set game status to game over
							status_RGB();
						}
						*(cell + 23) = *cell;	// move enemy down
						enemy_shoot(cell + 23, i, j, cellPos + 23); // shoot at new enemy position and current row
					}
					else
					{
						// game over when enemies hit shields
						if (*(cell + 1) == 'S' || *(cell + 1) == 's')
						{
							*address_GAMESTATUS = 3;	// set game status to game over
							status_RGB();
						}
						*(cell + 1) = *cell;	// move enemy right
						enemy_shoot(cell + 1, i, j, cellPos + 1); // shoot at new enemy position and current row
					}
					*cell = ' ';
				}
			}
			if (*cell == 'X') // mothership
			{
				if (*flag_MOTHER_DIRECTION == 1 && motherSpeed == 0) // moving right
				{
					if (motherAgainstRight)	*flag_MOTHER_SPAWN = 0;	// we missed the ship
					else					*(cell + 1) = *cell;	// move the mothership over
					*cell = ' ';	// delete current position
				}
			}
		}
	}
	//---/Main Loop---//
	
	//---Flag Updating---//
	if (enemyMoveDown)	// we moved the enemies down this tick
	{
		*flag_ENEMY_DOWN = 1;
		newBottomRow++;
	}
	else *flag_ENEMY_DOWN = 0;	// we did not move the enemies down this tick
	
	if (switchDirections)	*flag_ENEMY_LEFTRIGHT = 0; // if we are supposed to switch directions while going right, set direction to left (0)
	
	*flag_LEFTRIGHT = ' ';	// do not keep moving the player
	if (newBottomRow < 0) newBottomRow = 0;
	*flag_ENEMY_BOTTOM = newBottomRow;	// update the stored bottom row
	
	if (didFlush == 0) *flag_FLUSH_INPUTS = 0;	// flush out inputs
	
	if (enemiesPresent == 0)	// if there are no more enemies or motherships, go to the next level
	{
		*address_GAMESTATUS = 4;	// set game status to next level
		status_RGB();
		score_update += 50;	// you get 50 points for next level
	}
	else if (*flag_ENEMY_BOTTOM >= 14)	// if the enemies get to the 14th row (one above player row)
	{
		*address_GAMESTATUS = 3;	// set game status to game over
		status_RGB();
	}
	//---/Flag Updating---//
	
	//---Bullet Moving---//
	// move collided bullets
	if (bulletSpeed == 0)
	{
		for (int i = 1; i <= 15; i++) // row
		{
			for (int j = 1; j <= 21; j++) // column
			{
				int bulletPos = i*23 + j; // position in string is row*width + column
				char* bulletChar = address_BULLETS_P + bulletPos;
				char* boardChar = base_new + bulletPos;
				if (*bulletChar == '~')	// collision of bullets
				{
					if (*(boardChar + 23) == 'A')	// kill the player
					{
						kill_player(flag_DEATH_COUNT, flag_PLAYER_ANIMATION, boardChar, j);
					}
					else
					{
						*(boardChar + 23) = 'V';	// board
						*(bulletChar + 23) = 'V';	// player bullet
						*(address_BULLETS_E + bulletPos + 23) = 'V';	// enemy bullet
					}
					*(boardChar - 23) = '&';	// board
					*boardChar = ' ';
					*(bulletChar - 23) = '&';	// player bullet
					*bulletChar = ' ';
					*(address_BULLETS_E + bulletPos - 23) = '&';	// enemy bullet
					*(address_BULLETS_E + bulletPos) = ' ';
				}
			}
		}
	}
	
	// move player bullets
	for (int i = 1; i <= 15; i++) // row
	{
		for (int j = 1; j <= 21; j++) // column
		{
			int bulletPos = i*23 + j; // position in string is row*width + column
			char* bulletChar = address_BULLETS_P + bulletPos;
			char* boardChar = base_new + bulletPos;
			
			if (*bulletChar == '&')	// convert "just spawned" bullet into regular bullet
			{
				*bulletChar = '^';
				*boardChar = '^';
				continue;
			}
			if (*bulletChar != '^')	continue;	// ignore non-player bullets
			if (bulletSpeed == 0) // bullet speed
			{
				if (*bulletChar == '^')	*bulletChar = ' ';	// remove the bullet at the current position
				if (*boardChar == '^') *boardChar = ' ';
				
				if (*(boardChar - 23) == '-')	{ }	// stop at a wall
				else if (*(boardChar - 23) == 'O' || *(boardChar - 23) == 'M' || *(boardChar - 23) == 'W')	// kill an enemy
				{
					if (*(boardChar - 23) == 'O') score_update += 40;	// killing an 'O' enemy gives 40 points
					if (*(boardChar - 23) == 'M') score_update += 20;	// killing an 'M' enemy gives 20 points
					if (*(boardChar - 23) == 'W') score_update += 10;	// killing an 'W' enemy gives 10 points
					*(boardChar - 23) = ' ';	// kill the enemy
				}
				else if (*(boardChar - 23) == 'X')	// kill mothership
				{
					score_update += score_MOTHERSHIP;	// give the user points
					*flag_MOTHER_KILL_LEVEL = *flag_MOTHER_KILL_LEVEL + 1;	// increase mothership kill counters
					*flag_MOTHER_KILL_GAME = *flag_MOTHER_KILL_GAME + 1;
					*flag_MOTHER_SPAWN = 0;	// do not repeatedly spawn motherships
					*flag_MOTHER_ANIMATION = 1;	// start mothership killed animation
					*flag_MOTHER_POSITION = j;	// update mothership position
					*flag_MOTHER_SCORE = score_MOTHERSHIP / 10;	// update stored mothership score -- store 1/10 to fit in a byte
					*(boardChar - 23) = ' ';	// kill the mothership
				}
				else if (*(boardChar - 23) == 'S')	*(boardChar - 23) = 's';	// damage shields
				else if (*(boardChar - 23) == 's')	*(boardChar - 23) = ' ';
				else	// otherwise move the bullet up
				{
					*(bulletChar - 23) = '^';
					*(boardChar - 23) = '^';
				}
			}
		}
	}
	
	// move enemy bullets
	for (int i = 15; i >= 1; i--) // row
	{
		for (int j = 21; j >= 1; j--) // column
		{
			int bulletPos = i*23 + j; // position in string is row*width + column
			char* bulletChar = address_BULLETS_E + bulletPos;
			char* boardChar = base_new + bulletPos;
			
			if (*bulletChar == 'V')	// convert special "just spawned" bullet into regular bullet
			{
				*bulletChar = 'v';
				*boardChar = 'v';
				continue;
			}
			if (*bulletChar != 'v')	continue;	// ignore non-enemy bullets
			if (bulletSpeed == 0) // bullet speed
			{
				if (*bulletChar == 'v')	*bulletChar = ' ';	// remove the bullet at the current position
				if (*boardChar == 'v') *boardChar = ' ';
				if (*(boardChar + 23) == '-')	{ }	// stop at a wall
				else if (*(boardChar + 23) == 'A' && *flag_PLAYER_ANIMATION == 0)	// kill player
				{
					kill_player(flag_DEATH_COUNT, flag_PLAYER_ANIMATION, boardChar, j);
				}
				else if (*(boardChar + 23) == 'S')	*(boardChar + 23) = 's';	// damage shields
				else if (*(boardChar + 23) == 's')	*(boardChar + 23) = ' ';
				else if (*(boardChar + 23) == '^')	// collision of bullets
				{
					*(boardChar + 23) = '~';
					*(bulletChar + 23) = '~';	// update enemy bullet string
					*(address_BULLETS_P + bulletPos + 23) = '~';	// update player bullet string
				}
				else	// otherwise move the bullet down
				{
					*(bulletChar + 23) = 'v';
					*(boardChar + 23) = 'v';
				}
			}
		}
	}
	//---/Bullet Moving---//
	
	//---Miscellaneous---//
	// if mothership is not present and we need to spawn one, spawn it
	// (spawned at bottom so it does not skip a frame initially)
	if (mothershipPresent == 0 && *flag_MOTHER_SPAWN == 1 && *flag_MOTHER_ANIMATION == 0)
	{
		if (*flag_MOTHER_DIRECTION == 0)	*(base_new + 1*23 + 21) = 'X';	// if moving left, spawn on right
		else								*(base_new + 1*23 + 1) = 'X';	// spawn on left
		*flag_MOTHER_COUNT_LEVEL = *flag_MOTHER_COUNT_LEVEL + 1; // increase mothership spawn count
		*flag_MOTHER_COUNT_GAME = *flag_MOTHER_COUNT_GAME + 1;
	}
	
	update_score();	// update the score
	//---/Miscellaneous---//
};
