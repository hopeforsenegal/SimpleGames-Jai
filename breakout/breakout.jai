#import "String"; 
#import "Math"; 
#import "Basic";
#import "Random";
raylib :: #import,dir "../raylib/raylib";	//not sure why we aren't importing raylib/raymath

BoardWidthInBricks  :: 12;
BoardHeightInBricks :: 13;
BrickWidthInPixels  :: 64;
BrickHeightInPixels :: 24;

BrickOffsetX :: 16;
BrickOffsetY :: 16;

NumBrickTypes :: 4;

TextAlignment :: enum {
	Left; 
	Center;
	Right;
}

CollisionFace :: enum {
	None;
	Left;
	Top;
	Right;
	Bottom;
}

Rectangle :: struct {
	centerPosition: Vector2;
	size:           Vector2;
}

Ball :: struct {
 using rectangle: Rectangle;
	   velocity:  Vector2;
}

Brick :: struct {
	typeOf:  int;
	isAlive: bool;
}

InputScheme :: struct {
	leftButton:		raylib.KeyboardKey;
	rightButton:	raylib.KeyboardKey;
}

Pad :: struct {
 using rectangle: 	Rectangle;
 using input: 		InputScheme;
	   score:    	int;
	   velocity: 	Vector2;
}

player1: 	Pad;
ball: 		Ball;
bricks: 	[BoardWidthInBricks][BoardHeightInBricks]Brick;

InitialBallPosition: Vector2;
InitialBallVelocity: Vector2;

main :: () {
    raylib.InitWindow(800, 450, "JAI Breakout");
    defer raylib.CloseWindow();
	raylib.SetTargetFPS(60);
	
	SetupGame();
	
    while !raylib.WindowShouldClose() {
		dt := raylib.GetFrameTime();
		Update(dt);
		Draw();
    }
}

SetupGame :: (){
	screenSizeX := raylib.GetScreenWidth();
	screenSizeY := raylib.GetScreenHeight();
	
	{ // Setup bricks
		for i: 0..BoardWidthInBricks-1 {
			for j: 0..BoardHeightInBricks-1 {
				bricks[i][j].typeOf = cast(int)(random_get() % (NumBrickTypes));
				bricks[i][j].isAlive = true;
			}
		}
	}
	{ // Set up ball
		InitialBallPosition = make_vector2(cast(float)(screenSizeX/2), cast(float)(screenSizeY - 20));
		InitialBallVelocity = make_vector2(50, -25);
		ball.velocity = InitialBallVelocity;
		ball.centerPosition = InitialBallPosition;
		ball.size = make_vector2(10, 10);
	}
	{ // Set up player
		player1.size = make_vector2(50, 5);
		player1.velocity = make_vector2(100, 100);
		player1.centerPosition = make_vector2(cast(float)(screenSizeX / 2), cast(float)(screenSizeY - 10)); 
		player1.input = InputScheme.{
			.KEY_A,
			.KEY_D,
		};
	}
}

Update :: (deltaTime:float64){
	height := raylib.GetScreenHeight();
	width := raylib.GetScreenWidth();
	collisionFace := CollisionFace.None;
	
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
	}
	{ // Update ball
		ball.centerPosition.x += cast(float)deltaTime * ball.velocity.x;
		ball.centerPosition.y += cast(float)deltaTime * ball.velocity.y;
	}
	// Collisions
	{ // ball boundary collisions
		isBallOnBottomScreenEdge := ball.centerPosition.y > cast(float)(height);
		isBallOnTopScreenEdge := ball.centerPosition.y < cast(float)(0);
		isBallOnLeftRightScreenEdge := ball.centerPosition.x > cast(float)(width) || ball.centerPosition.x < cast(float)(0);
		if (isBallOnBottomScreenEdge) {
			ball.centerPosition = InitialBallPosition;
			ball.velocity = InitialBallVelocity;
		}
		if (isBallOnTopScreenEdge) {
			ball.velocity.y *= -1;
		}
		if (isBallOnLeftRightScreenEdge) {
			ball.velocity.x *= -1;
		}
	}
	{ // ball brick collisions
		for i: 0..BoardWidthInBricks-1 {
			for j: 0..BoardHeightInBricks-1 {
				brick := *bricks[i][j];
				if !brick.isAlive {
					continue;
				}

				// Coords
				brickX := cast(float)(BrickOffsetX + (i * BrickWidthInPixels));
				brickY := cast(float)(BrickOffsetY + (j * BrickHeightInPixels));

				// Ball position
				ballX := ball.centerPosition.x - (ball.size.x / 2);
				ballY := ball.centerPosition.y - (ball.size.y / 2);

				// Center Brick
				brickCenterX := brickX + (BrickWidthInPixels / 2);
				brickCenterY := brickY + (BrickHeightInPixels / 2);

				hasCollisionX := ballX+ball.size.x >= brickX && brickX+BrickWidthInPixels >= ballX;
				hasCollisionY := ballY+ball.size.y >= brickY && brickY+BrickHeightInPixels >= ballY;

				if hasCollisionX && hasCollisionY {
					brick.isAlive = false;

					// Determine which face of the brkrampick was hit
					ymin := Max(brickY, ballY);
					ymax := Min(brickY+BrickHeightInPixels, ballY+ball.size.y);
					ysize := ymax - ymin;
					xmin := Max(brickX, ballX);
					xmax := Min(brickX+BrickWidthInPixels, ballX+ball.size.x);
					xsize := xmax - xmin;
					if xsize > ysize && ball.centerPosition.y > brickCenterY {
						collisionFace = .Bottom;
					} else if xsize > ysize && ball.centerPosition.y <= brickCenterY {
						collisionFace = .Top;
					} else if xsize <= ysize && ball.centerPosition.x > brickCenterX {
						collisionFace = .Right;
					} else if xsize <= ysize && ball.centerPosition.x <= brickCenterX {
						collisionFace = .Left;
					} else {
						// Could assert or panic here
					}

					break i;
				}
			}
		}
	}
	{ // Update ball after collision
		if collisionFace != .None {
			hasPositiveX := ball.velocity.x > 0;
			hasPositiveY := ball.velocity.y > 0;
			if  (collisionFace == .Top    && hasPositiveX  && hasPositiveY) ||
				(collisionFace == .Top    && !hasPositiveX && hasPositiveY) ||
				(collisionFace == .Bottom && hasPositiveX  && !hasPositiveY) ||
				(collisionFace == .Bottom && !hasPositiveX && !hasPositiveY) {
				ball.velocity.y *= -1;
			}
			if  (collisionFace == .Left  && hasPositiveX  && hasPositiveY) ||
				(collisionFace == .Left  && hasPositiveX  && !hasPositiveY) ||
				(collisionFace == .Right && !hasPositiveX && hasPositiveY) ||
				(collisionFace == .Right && !hasPositiveX && !hasPositiveY) {
				ball.velocity.x *= -1;
			}
		}
	}
	{ // Update ball after pad collision
		if (DetectBallTouchesPad(ball, player1)) {
			previousVelocity := ball.velocity;
			distanceX := ball.centerPosition.x - player1.centerPosition.x;
			percentage := distanceX / (player1.size.x / 2);
			ball.velocity.x = InitialBallVelocity.x * percentage;
			ball.velocity.y *= -1;
			newVelocity := Vector2Normalize(ball.velocity) * (length(previousVelocity) * 1.1);
			ball.velocity = newVelocity;
		}
	}
	{ // Detect all bricks popped
		hasAtLeastOneBrick := false;
		for i: 0..BoardWidthInBricks-1 {
			for j: 0..BoardHeightInBricks-1 {
				brick := bricks[i][j];
				if brick.isAlive {
					hasAtLeastOneBrick = true;
					break i;
				}
			}
		}
		if !hasAtLeastOneBrick {
			SetupGame();
		}
	}
}

Draw :: (){
    raylib.BeginDrawing();
    defer raylib.EndDrawing();
    raylib.ClearBackground(raylib.BLACK);
	
	height := raylib.GetScreenHeight();
	width := raylib.GetScreenWidth();
	
	{ // Draw player
		raylib.DrawRectangle(cast(s32)(player1.centerPosition.x-(player1.size.x/2)), cast(s32)(player1.centerPosition.y-(player1.size.y/2)), cast(s32)(player1.size.x), cast(s32)(player1.size.y), raylib.WHITE);		
	}
	{ // Draw alive bricks
		for i: 0..BoardWidthInBricks-1 {
			for j: 0..BoardHeightInBricks-1 {
				if !bricks[i][j].isAlive {
					continue;
				}
				raylib.DrawRectangle(cast(s32)(BrickOffsetX+(i*BrickWidthInPixels)), cast(s32)(BrickOffsetY+(j*BrickHeightInPixels)), cast(s32)(BrickWidthInPixels), cast(s32)(BrickHeightInPixels), TypeToColor(bricks[i][j].typeOf));
			}
		}
	}
	{ // Draw Ball
		raylib.DrawRectangle(cast(s32)(ball.centerPosition.x-(ball.size.x/2)), cast(s32)(ball.centerPosition.y-(ball.size.y/2)), cast(s32)(ball.size.x), cast(s32)(ball.size.y), raylib.WHITE);
	}
}

DetectBallTouchesPad :: (ball:Ball, pad:Pad) ->bool {
	ballX := ball.centerPosition.x - (ball.size.x / 2);
	ballY := ball.centerPosition.y - (ball.size.y / 2);
	padX := pad.centerPosition.x - (pad.size.x / 2);
	padY := pad.centerPosition.y - (pad.size.y / 2);
	if ballY+(ball.size.y/2) >= padY && ballX >= padX && ballX <= padX+pad.size.x {
		return true;
	}
	return false;
}

TypeToColor::(typeOf:int) ->raylib.Color {
	if typeOf == {
		case 0; return raylib.WHITE;
		case 1; return raylib.RED;
		case 2; return raylib.GREEN;
		case 3; return raylib.BLUE;
	}
	return raylib.WHITE;
}

Vector2Length :: (v: Vector2) -> float { 	// not sure why we aren't importing raylib/raymath
    return sqrt((v.x*v.x) + (v.y*v.y));
}

Vector2Scale :: (v: Vector2, scale: float) -> Vector2 {
    return make_vector2(v.x*scale, v.y*scale);
}

Vector2Normalize :: (v: Vector2) -> Vector2 {
    return Vector2Scale(v, 1/Vector2Length(v));
}
