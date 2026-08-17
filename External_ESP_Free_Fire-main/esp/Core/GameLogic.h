#ifndef GameLogic_h
#define GameLogic_h

#import "MemoryUtils.h"
#import "UnityMath.h"

#pragma mark - Function Game

uint64_t getMatchGame(uint64_t Moudule_Base);
uint64_t getMatch(uint64_t matchgame);
uint64_t CameraMain(uint64_t matchgame);
float* GetViewMatrix(uint64_t cameraMain);
uint64_t getTransNode(uint64_t BodyPart);
uint64_t getHead(uint64_t player);
uint64_t getRightToeNode(uint64_t player);
uint64_t getLocalPlayer(uint64_t match);
int GetDataUInt16(uint64_t player, int varID);
int get_CurHP(uint64_t Player);
int get_MaxHP(uint64_t Player);
bool isLocalTeamMate(uint64_t localPlayer, uint64_t Player);

#endif