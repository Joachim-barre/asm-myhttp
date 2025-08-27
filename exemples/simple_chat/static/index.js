let lastSent = ""

document.getElementById("send_form").addEventListener("submit", function (event) {
    event.preventDefault();

    var formData = new FormData(this);

    lastSent = formData.get("to_send")

    fetch("/send", {
        method: "POST",
            body: formData.get("to_send")
        })
    .catch(error => {
        console.error("Error:", error);
    });
});

const evtSource = new EventSource("/events");
const messageList = document.getElementById("messages");

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

