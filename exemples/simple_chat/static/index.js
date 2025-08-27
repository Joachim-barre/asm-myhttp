let lastSent = ""
const messageList = document.getElementById("messages");

function appendMessage(message, is_sent) {
    if (is_sent){
        lastSent = message
    } else if (lastSent == message) {
        lastSent = ""
        return
    }

    const newElement = document.createElement("li");

    newElement.textContent = `${message}`;
    if (is_sent) {
        newElement.classList.add('message_sent');
    } else {
        newElement.classList.add('message_recived');
    }
    messageList.appendChild(newElement);

    messageList.scrollTop=messageList.scrollHeight;
}

document.getElementById("send_form").addEventListener("submit", function (event) {
    event.preventDefault();

    var formData = new FormData(this);
    var message = formData.get("to_send")

    appendMessage(message, true)

    fetch("/send", {
        method: "POST",
            body: message
        })
    .catch(error => {
        console.error("Error:", error);
    });
});

const evtSource = new EventSource("/events");

evtSource.onmessage = (e) => {
    appendMessage(e.data, false)    
};

evtSource.addEventListener("connected", (e) => {
    console.log("successfuly connected")
})

