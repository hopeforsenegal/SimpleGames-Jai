#import "Math";
#import "Basic";
#import "Random";
raylib :: #import,dir "../raylib/raylib";

TextAlignment :: enum {
	Left; 
	Center;
	Right;
}

BulletCooldownSeconds 	:: 0.3;
MaxNumBullets  			:: 50;
MaxNumEnemies 			:: 50;

Rectangle :: struct {
	centerPosition: Vector2;
	size:           Vector2;
}

InputScheme :: struct {
	leftButton:		raylib.KeyboardKey;
	rightButton:	raylib.KeyboardKey;
	shootButton:	raylib.KeyboardKey;
}

Pad :: struct {
 using rectangle: 	Rectangle;
 using input: 		InputScheme;
	   score:    	int;
	   velocity: 	Vector2;
}

Bullet :: struct {
 using rectangle: 	Rectangle;
	   velocity: 	Vector2;
	   color:    	raylib.Color;
	   isActive: 	bool;
}

Enemy :: struct {
 using rectangle: 	Rectangle;
	   velocity: 	Vector2;
	   color:    	raylib.Color;
	   isActive: 	bool;
}

bullets: [MaxNumBullets]Bullet;
enemies: [MaxNumEnemies]Enemy;
player1: Pad;
m_TimerBulletCooldown: float32;
m_TimerSpawnEnemy: float32;
numEnemiesThisLevel: int;
numEnemiesToSpawn: int;
numEnemiesKilled: int;
numLives:= 3;
IsGameOver: bool;
IsWin: bool;

InitialPlayerPosition: Vector2;

main :: () {
    raylib.InitWindow(800, 450, "JAI Space Invaders");
    defer raylib.CloseWindow();
	raylib.SetTargetFPS(60);

	screenSizeX := raylib.GetScreenWidth();
	screenSizeY := raylib.GetScreenHeight();
	InitialPlayerPosition = make_vector2(cast(float)(screenSizeX/2), cast(float)(screenSizeY - 10));

	{ // Set up player
		player1.size = make_vector2(25, 25);
		player1.velocity = make_vector2(100, 100);
		player1.centerPosition = InitialPlayerPosition;
		player1.input = InputScheme.{
			.KEY_A,
			.KEY_D,
			.KEY_SPACE,
		};
	}
	{ // init bullets
		for i: 0..MaxNumBullets-1 {
			bullet := *bullets[i];
			{
				bullet.velocity = make_vector2(0, 400);
				bullet.size = make_vector2(5, 5);
			}
		}
	}
	{ // init enemies
		for i: 0..MaxNumEnemies-1 {
			enemy := *enemies[i];
			{
				enemy.velocity = make_vector2(0, 40);
				enemy.size = make_vector2(20, 20);
				enemy.centerPosition = make_vector2(random_get_within_range(0.0, cast(float)screenSizeX), cast(float)-20);
			}
		}
		numEnemiesToSpawn = 10;
		numEnemiesThisLevel = 10;
	}

    while !raylib.WindowShouldClose() {
        reset_temporary_storage();	// reset the memory used by tprint
		dt := raylib.GetFrameTime();
		Update(dt);
		Draw();
    }
}

Update :: (deltaTime:float64){
	height := raylib.GetScreenHeight();
	width := raylib.GetScreenWidth();

	if IsGameOver || IsWin {
		return;
	}

	{ // Update Player
		if(raylib.IsKeyDown(player1.rightButton)){
			// Update position
			player1.centerPosition.x += cast(float)(deltaTime * player1.velocity.x);
			// Clamp on right edge
			if(player1.centerPosition.x + (player1.size.x/2) > cast(float)width){
				player1.centerPosition.x = width - (player1.size.x /2);
			}
		}
		if(raylib.IsKeyDown(player1.leftButton)){
			// Update position
			player1.centerPosition.x -= cast(float)(deltaTime * player1.velocity.x);
			// Clamp on left edge
			if(player1.centerPosition.x - (player1.size.x/2) < 0){
				player1.centerPosition.x = player1.size.x /2;
			}
		}
		if HasHitTime(*m_TimerBulletCooldown, deltaTime) {
			if raylib.IsKeyDown(player1.shootButton) {
				for i: 0..MaxNumBullets-1 {
					bullet := *bullets[i];
					if !bullet.isActive {
						m_TimerBulletCooldown = BulletCooldownSeconds;
						bullet.isActive = true;
						{
							bullet.centerPosition.x = player1.centerPosition.x;
							bullet.centerPosition.y = player1.centerPosition.y + (player1.size.y / 4);
							break;
						}
					}
				}
			}
		}
	}
	{ // Update active bullets
		for i: 0..MaxNumBullets-1 {
			bullet := *bullets[i];
			// Movement
			if bullet.isActive {
				bullet.centerPosition.y -= cast(float)(bullet.velocity.y * deltaTime);

				// Went off screen
				if bullet.centerPosition.y+(bullet.size.y/2) <= 0 {
					bullet.isActive = false;
				}
			}
		}
	}
	{ // Update active enemies
		for i: 0..numEnemiesThisLevel-1 {
			enemy := *enemies[i];
			//Movement
			if enemy.isActive {
				enemy.centerPosition.y += cast(float)(enemy.velocity.y * deltaTime);

				// Went off screen
				if enemy.centerPosition.y-(enemy.size.y/2) >= cast(float)(height) {
					enemy.centerPosition = make_vector2(random_get_within_range(0.0, cast(float)width), cast(float)-20);
				} else {
					enemyX := enemy.centerPosition.x - (enemy.size.x / 2);
					enemyY := enemy.centerPosition.y - (enemy.size.y / 2);
					{ // bullet | enemy collision
						for j: 0..MaxNumBullets-1 {
							bullet := *bullets[j];
							bulletX := bullet.centerPosition.x - (bullet.size.x / 2);
							bulletY := bullet.centerPosition.y - (bullet.size.y / 2);

							hasCollisionX := bulletX+bullet.size.x >= enemyX && enemyX+enemy.size.x >= bulletX;
							hasCollisionY := bulletY+bullet.size.y >= enemyY && enemyY+enemy.size.y >= bulletY;

							if hasCollisionX && hasCollisionY {
								bullet.isActive = false;
								enemy.isActive = false;
								{
									numEnemiesKilled = numEnemiesKilled + 1;
									IsWin = numEnemiesKilled >= numEnemiesThisLevel;
									break;
								}
							}
						}
					}
					{ // player | enemy collision
						bulletX := player1.centerPosition.x - (player1.size.x / 2);
						bulletY := player1.centerPosition.y - (player1.size.y / 2);

						hasCollisionX := bulletX+player1.size.x >= enemyX && enemyX+enemy.size.x >= bulletX;
						hasCollisionY := bulletY+player1.size.y >= enemyY && enemyY+enemy.size.y >= bulletY;

						if hasCollisionX && hasCollisionY {
							enemy.isActive = false;
							{
								player1.centerPosition = InitialPlayerPosition;
								numLives = numLives - 1;
								IsGameOver = numLives <= 0;
							}
						}
					}
				}
			}
		}
	}
	{ // Spawn enemies
		canSpawn := HasHitInterval(*m_TimerSpawnEnemy, 2.0, deltaTime);
		for i: 0..MaxNumEnemies-1 {
			enemy := *enemies[i];
			// Spawn
			if !enemy.isActive {
				if canSpawn && numEnemiesToSpawn > 0 {
					numEnemiesToSpawn = numEnemiesToSpawn - 1;
					enemy.isActive = true;
					{
						enemy.centerPosition = make_vector2(random_get_within_range(0.0, cast(float)width), cast(float)-20);
						break;
					}
				}
			}
		}
	}
}

Draw :: (){
    raylib.BeginDrawing();
    defer raylib.EndDrawing();
    raylib.ClearBackground(raylib.WHITE);
	
	height := raylib.GetScreenHeight();
	width := raylib.GetScreenWidth();

	{ // Draw player
		raylib.DrawRectangle(cast(s32)(player1.centerPosition.x-(player1.size.x/2)), cast(s32)(player1.centerPosition.y-(player1.size.y/2)), cast(s32)(player1.size.x), cast(s32)(player1.size.y), raylib.BLACK);		
	}
	{ // Draw the bullets
		for i: 0..MaxNumBullets-1 {
			bullet := bullets[i];
			if bullet.isActive {
				raylib.DrawRectangle(cast(s32)(bullet.centerPosition.x-(bullet.size.x/2)), 
									 cast(s32)(bullet.centerPosition.y-(bullet.size.y/2)), 
									 cast(s32)(bullet.size.x), 
									 cast(s32)(bullet.size.y), 
									 raylib.ORANGE);
			}
		}
	}
	{ // Draw the enemies
		for i: 0..MaxNumEnemies-1 {
			enemy := enemies[i];
			if enemy.isActive {
				raylib.DrawRectangle(cast(s32)(enemy.centerPosition.x-(enemy.size.x/2)), 
									 cast(s32)(enemy.centerPosition.y-(enemy.size.y/2)), 
									 cast(s32)(enemy.size.x), 
									 cast(s32)(enemy.size.y), 
									 raylib.BLUE);
			}
		}
	}
	{ // Draw Info
		DrawText(tprint("Lives %", numLives), .Left, 15, 5, 20);

		if IsGameOver {
			DrawText("Game Over", .Center, width/2, height/2, 50);
		}
		if IsWin {
			DrawText("You Won", .Center, width/2, height/2, 50);
		}
	}
}

DrawText :: (text:string, alignment:TextAlignment, posX:s32, posY:s32, fontSize :s32){
	fontColor := raylib.DARKGRAY;
	if alignment == .Left {
		 raylib.DrawText(text.data, posX, posY, fontSize, fontColor);
	} else if alignment == .Center {
		scoreSizeLeft := raylib.MeasureText(text.data, fontSize);
		raylib.DrawText(text.data, (posX - scoreSizeLeft/2), posY, fontSize, fontColor);
	} else if alignment == .Right {
		scoreSizeLeft := raylib.MeasureText(text.data, fontSize);
		raylib.DrawText(text.data, (posX - scoreSizeLeft), posY, fontSize, fontColor);
	}
}

HasHitInterval::(timeRemaining:*float, resetTime:float, deltaTime:float64) ->bool {
	<<timeRemaining -= cast(float)deltaTime;
	if <<timeRemaining <= 0 {
		<<timeRemaining = resetTime;
		return true;
	}
	return false;
}

HasHitTime :: (timeRemaining:*float, deltaTime:float64) ->bool {
	<<timeRemaining = cast(float)(<<timeRemaining - deltaTime);
	return <<timeRemaining <= 0;
}
