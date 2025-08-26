document.getElementById("send_form").addEventListener("submit", function (event) {
    event.preventDefault();

    var formData = new FormData(this);

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
    const newElement = document.createElement("li");

    newElement.textContent = `${e.data}`;
    newElement.classList.add('message_recived');
    messageList.appendChild(newElement);
};
