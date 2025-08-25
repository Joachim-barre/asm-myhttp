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
