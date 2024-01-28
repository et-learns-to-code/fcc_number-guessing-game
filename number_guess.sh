#!/bin/bash

PSQL="psql --username=freecodecamp --dbname=number_guess -t --no-align -c"

GENERATE_SECRET_NUMBER() {
  SECRET_NUMBER=$(( RANDOM % 1000 + 1 ))
}

ASK_FOR_GUESS() {
  # increments number of guesses each time a new guess is made
  (( NUMBER_OF_GUESSES++ ))
  if [[ $1 ]]
  then
    echo -e "\n$1"
  fi
  read GUESS
}

echo -e "\nEnter your username:"
read USERNAME

# checks whether username is under 22 characters
if [[ $USERNAME =~ ^.{23,}$ ]]
then
  echo "Your username must be 22 characters or less."
  exit
# checks whether username is empty
elif [[ $USERNAME =~ ^$ ]]
then 
  echo "Your username cannot be empty."
  exit
else
  USER_ID=$($PSQL "select user_id from users where username='$USERNAME';")
  if [[ -z $USER_ID ]]
  then
    # inserts new user username into the database
    INSERT_NEW_USER_RESULT=$($PSQL "insert into users (username) values ('$USERNAME');")
    if [[ $INSERT_NEW_USER_RESULT == "INSERT 0 1" ]]
    then
      sleep 1
      echo -e "\nWelcome, $USERNAME! It looks like this is your first time here."
      USER_ID=$($PSQL "select user_id from users where username='$USERNAME';")
    fi
  else 
    # retrieves user data for existing user
    USER_DATA=$($PSQL "select games_played, best_game from users where user_id=$USER_ID;")
    IFS="|" read GAMES_PLAYED BEST_GAME <<< "$USER_DATA"
    sleep 1
    echo -e "\nWelcome back, $USERNAME! You have played $GAMES_PLAYED games, and your best game took $BEST_GAME guesses."
  fi
fi

# guessing game starts
GENERATE_SECRET_NUMBER 
sleep 2 
echo -e "\nGuess the secret number between 1 and 1000:"
read GUESS
NUMBER_OF_GUESSES=0

# checks that guess is an integer and prompts user until guess matches secret number
until [[ $GUESS -eq $SECRET_NUMBER ]]
do
  if [[ ! $GUESS =~ ^[0-9]+$ ]]
  then 
    ASK_FOR_GUESS "That is not an integer, guess again:"
    # guesses that are non-integers do not count towards number of guesses
    (( NUMBER_OF_GUESSES-- ))
  else
    if [[ $GUESS -gt $SECRET_NUMBER ]]
    then
      ASK_FOR_GUESS "It's lower than that, guess again:"
    else
      ASK_FOR_GUESS "It's higher than that, guess again:"
    fi    
  fi
done

# user managed to guess the secret number
if [[ $GUESS -eq $SECRET_NUMBER ]]
then
  (( NUMBER_OF_GUESSES++ ))
  echo -e "\nYou guessed it in $NUMBER_OF_GUESSES tries. The secret number was $SECRET_NUMBER. Nice job!"
  # updates user's number of games played and best game results in database
  UPDATE_GAMES_PLAYED=$($PSQL "update users set games_played=($GAMES_PLAYED + 1) where user_id=$USER_ID;")
  if [[ $NUMBER_OF_GUESSES -lt $BEST_GAME || -z $BEST_GAME ]]
  then
    UPDATE_BEST_GAME=$($PSQL "update users set best_game=$NUMBER_OF_GUESSES where user_id=$USER_ID;")
  fi
fi
