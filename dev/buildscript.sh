#!/bin/bash
SERVER_IP=""
SERVER_NAME=""
PERSONAL_FOLDER=""


if [ "$1" == "server" ]; then
    # Build and deploy the server
    echo "Building and deploying the server..."
    rm -f ${PROJECT}.tar
    sudo docker image rm ${PROJECT}
    sudo docker image prune -f
    sudo docker build -t ${PROJECT} .
    sudo docker images
    sudo docker save -o ${PROJECT}.tar ${PROJECT}:latest
    # sudo openvpn guest-1.ovpn
    scp -i /home/${PERSONAL_FOLDER}/.ssh/id_rsa ${PROJECT}.tar ${SERVER_NAME}@${SERVER_IP}:/home/${SERVER_NAME}/${PERSONAL_FOLDER}/${PROJECT}
    ssh -i /home/${PERSONAL_FOLDER}/.ssh/id_rsa -t ${SERVER_NAME}@${SERVER_IP} `cd /home/${SERVER_NAME}/${PERSONAL_FOLDER}/${PROJECT} && sudo chmod +x buildscript.sh && sudo ./buildscript.sh && exec bash`
    
elif [ "$1" == "product" ]; then 
    echo "Building product..."
    ssh -i /home/${PERSONAL_FOLDER}/.ssh/id_rsa -t ${SERVER_NAME}@${SERVER_IP} `cd /home/${SERVER_NAME}/${PERSONAL_FOLDER}/${PROJECT} && sudo chmod +x buildscript.sh && sudo ./buildscript.sh && exec bash`

else
    # Build and deploy the client
    echo "Building the client..."
    cd ..
    cd ${PROJECT}-client
    sudo cp .env.prod .env
    npm run build
    sudo cp .env.dev .env
    cd ..

    # Check if the ${PROJECT}-static folder exists
    if [ ! -d "./${PROJECT}-server/${PROJECT}-static" ]; then
        mkdir -p ./${PROJECT}-server/${PROJECT}-static
    else
        sudo rm -rf ./${PROJECT}-server/${PROJECT}-static/* # Delete all contents if it exists
    fi

    sudo cp -r ./${PROJECT}-client/build/* ./${PROJECT}-server/${PROJECT}-static/

    echo "Building and deploying the server..."
    cd ${PROJECT}-server
    rm -f ${PROJECT}.tar
    sudo docker image rm ${PROJECT}
    sudo docker image prune -f
    sudo docker build -t ${PROJECT} .
    sudo docker images
    sudo docker save -o ${PROJECT}.tar ${PROJECT}:latest
    scp -i /home/${PERSONAL_FOLDER}/.ssh/id_rsa ${PROJECT}.tar ${SERVER_NAME}@${SERVER_IP}:/home/${SERVER_NAME}/${PERSONAL_FOLDER}/${PROJECT}
    ssh -i /home/${PERSONAL_FOLDER}/.ssh/id_rsa -t ${SERVER_NAME}@${SERVER_IP} `cd /home/${SERVER_NAME}/${PERSONAL_FOLDER}/${PROJECT} && sudo chmod +x buildscript.sh && sudo ./buildscript.sh && exec bash`
fi
