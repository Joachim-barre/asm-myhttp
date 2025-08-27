let lastSent = ""
const messageList = document.getElementById("messages");

document.getElementById("send_form").addEventListener("submit", function (event) {
    event.preventDefault();

    var formData = new FormData(this);
    var message = formData.get("to_send")

    lastSent = message

    const newElement = document.createElement("li");

    newElement.textContent = `${message}`;
    newElement.classList.add('message_sent');
    messageList.appendChild(newElement);

    fetch("/send", {
        method: "POST",
            body: formData.get("message")
        })
    .catch(error => {
        console.error("Error:", error);
    });
});

const evtSource = new EventSource("/events");

evtSource.onmessage = (e) => {
    if (lastSent == e.data) {
        lastSent = ""
        return
    }

    const newElement = document.createElement("li");

    newElement.textContent = `${e.data}`;
    newElement.classList.add('message_recived');
    messageList.appendChild(newElement);
};

evtSource.addEventListener("connected", (e) => {
    console.log("successfuly connected")
})

