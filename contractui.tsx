import React from 'react';
import { useButtonGame } from './button-game-hooks';
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Timer, Trophy, Wallet } from "lucide-react";

const formatAddress = (address: string) => 
  `${address?.slice(0, 6)}...${address?.slice(-4)}`;

const formatTime = (seconds: number) => {
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  return `${mins}:${secs.toString().padStart(2, '0')}`;
};

export default function ButtonGame() {
  const {
    currentGameId,
    entryAmount,
    timeLeft,
    currentPot,
    latestPlayer,
    isCurrentPlayer,
    playerStats,
    pressButton,
    claimPrize,
    isPressingButton,
    isClaiming,
  } = useButtonGame();

  const canClaim = isCurrentPlayer && timeLeft === 0;

  return (
    <div className="max-w-2xl mx-auto p-4 space-y-4">
      <Card className="w-full">
        <CardHeader>
          <CardTitle className="text-2xl">The Button Game</CardTitle>
          <CardDescription>
            Press the button to win the pot! Entry costs {entryAmount} ETH
          </CardDescription>
        </CardHeader>

        <CardContent className="space-y-4">
          {/* Game Status */}
          <div className="grid grid-cols-2 gap-4">
            <div className="bg-secondary p-4 rounded-lg">
              <div className="text-sm text-muted-foreground">Current Pot</div>
              <div className="text-2xl font-bold flex items-center gap-2">
                <Wallet className="w-5 h-5" />
                {currentPot} ETH
              </div>
            </div>
            
            <div className="bg-secondary p-4 rounded-lg">
              <div className="text-sm text-muted-foreground">Time Remaining</div>
              <div className="text-2xl font-bold flex items-center gap-2">
                <Timer className="w-5 h-5" />
                {formatTime(timeLeft)}
              </div>
            </div>
          </div>

          {/* Current Leader */}
          <Alert>
            <Trophy className="w-4 h-4" />
            <AlertTitle>Current Leader</AlertTitle>
            <AlertDescription>
              {latestPlayer ? formatAddress(latestPlayer) : 'No players yet'}
            </AlertDescription>
          </Alert>

          {/* Player Stats */}
          <div className="bg-secondary/50 p-4 rounded-lg">
            <div className="text-sm text-muted-foreground mb-2">Your Stats</div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <div className="text-sm text-muted-foreground">Total Contributed</div>
                <div className="font-medium">{playerStats.totalContributed} ETH</div>
              </div>
              <div>
                <div className="text-sm text-muted-foreground">Total Won</div>
                <div className="font-medium">{playerStats.totalWon} ETH</div>
              </div>
            </div>
          </div>
        </CardContent>

        <CardFooter className="flex flex-col gap-2">
          <Button 
            className="w-full"
            size="lg"
            onClick={() => pressButton()}
            disabled={isPressingButton}
          >
            {isPressingButton ? "Pressing Button..." : "Press Button"}
          </Button>

          {canClaim && (
            <Button
              className="w-full"
              variant="secondary"
              onClick={() => claimPrize(currentGameId)}
              disabled={isClaiming}
            >
              {isClaiming ? "Claiming Prize..." : "Claim Prize"}
            </Button>
          )}
        </CardFooter>
      </Card>
    </div>
  );
}