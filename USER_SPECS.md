# User written specifications to start the project

## Overview

The project is a board game collection management system which consists of two applications: a web application and a mobile application. The web application is the main interface for users while the mobile component is mainly for barcode scanning of their board games. The web application will run in a docker container and have a SQLite database component for storing user data, links to boardgamegeek.com, and users' board game collections - synced to boardgamegeek.com.

### Web application

- Running on boardgames.tendimensions.com
- Docker container for deployment
- User can create an account, log in, manage their profile, access their board game collection, and create an API key to be used with the mobile app component which is used for scanning barcodes of applications- Users will be able to create API keys within their profile for the mobile application to be able to access their collection data and send barcode scan results to the web application to be stored in the database.
- When a user creates an account on the web application, if they provide their boardgamegeek.com username, the web application will attempt to sync their collection data from boardgamegeek.com and store it in the database. This will allow users to have a local copy of their collection data that can be accessed and managed through the web application and mobile application.
- Users can then add to their collection by simply scanning the barcode of a game with the mobile application, which will send the data to the web application to be stored in the database and linked to the user's collection.
- TBD: Investigate how the API from boardgamegeek.com can allow for users to "push" board game data to their boardgamegeek.com collection from the web application when they add games to their collection through the web application or mobile application. This would allow users to have their collection data synced between the web application and boardgamegeek.com without having to manually update their collection on boardgamegeek.com.
- Users on the web site will also be able to create "Party Lists" where they can flag certain games that are being brought to a party.
  - These "party lists" can be shared with other users on the system and compiled into a single list so users can see duplicates and potentially request other users to bring certain games from their collection.
  - "Party Lists" can be assembled either by the users on the web application or by the mobile application by scanning barcodes of games in a specific "mode" on the mobile app.

#### User Interface

- Base the web application UI using [sample-style.css](this sample css).
- The UI should start on a login screen with username and password with "Forgot password" and "Create account" options.
- Once authenticated, the main screen will be the collection of board games the user has. It will start empty.
- On the main screen there will be a button that says "Sync from BoardGameGeek.com" which will attempt to sync the user's collection data from boardgamegeek.com and store it in the database. This will be a safe operation, not overwriting any existing data in the database, but rather adding to it and linking it to the user's collection.
- Under their profile, users will be able to edit their username, but NOT their email address or boardgamegeek.com username.
- There will be a separate screen that's mobile friendly for the purposes of generating an API key for the mobile application.

### Mobile application

- Running on Android and iOS
- Users can log in with their account created on the web application and use the API key generated from the web application to access their collection data and send barcode scan results to the web application to be stored in the database.
- Users would download the mobile application, open boardgames.tendimensions.com on their phone's browser, log in to their account, and generate an API key for the mobile application. They would then copy the API key and enter it into the mobile application to link their account and allow the mobile application to access their collection data and send barcode scan results to the web application.
- The barcode scanning feature of the mobile application should be "continuous" in the sense that users can scan multiple barcodes in a row without having to stop and start the scanning process for each individual game. A simple 'beep' will sound when a successful scan has been made and the data has been sent to the web application to be stored in the database.
- UPC codes will be handled by hitting endpoints provided at this site: https://gameupc.com/ to retrieve the game data associated with the UPC code.

## Technical Specifications

- Programming language TBD, but for the mobile application, probably Flutter with native libraries for the barcode scanning functionality. For the web application, a popular web framework such as Django or Flask for Python, or Express for Node.js could be used.
- Consists of two applications: a web application running in a docker container and a mobile application running on Android and iOS.
- SQLite database for storing user data, links to boardgamegeek.com, and users' board game collections - synced to boardgamegeek.com.
- API endpoints for the mobile application to access user collection data and send barcode scan results to the web application to be stored in the database.
- Integration with boardgamegeek.com API for syncing user collection data and potentially pushing updates to boardgamegeek.com when users add games to their collection through the web application or mobile application.
- Integration with gameupc.com API for retrieving game data associated with UPC codes scanned by the mobile application.
- The web application "Create Account" option will use SMTP credential to email the user with a verification link to verify their email address and allow them to set a password for their email and username.
- Usernames and emails must be unique in the system, and the web application will check for this when a user attempts to create an account. If a username or email is already in use, the web application will return an error message prompting the user to choose a different username or email.
- SMTP credentials will need to be saved securely in the web application for sending verification emails to users when they create an account.
- Nginx will be used as a reverse proxy to route traffic to the web application running in the docker container. The nginx configuration will need to be set up to route traffic from boardgames.tendimensions.com to the appropriate port where the web application is running in the docker container.
- The web application will need to be configured to run in a docker container, and the necessary Dockerfile and docker-compose.yml files will need to be created to set up the container and its dependencies, including the SQLite database and any necessary environment variables for SMTP credentials and API keys for boardgamegeek.com and gameupc.com.
- CodeMagic.io will be used for compiling and building the mobile application for both Android and iOS platforms. The necessary configuration files for CodeMagic.io will need to be created to set up the build process for the mobile application, including any necessary environment variables for API keys and credentials for accessing the web application and third-party APIs.
- Google's Firebase will be used for mobile application distribution.