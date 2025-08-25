document.getELementById("send").addEventListener("submit", function (event) {
    event.preventDefault();

    var formData = new FormData(this);

    fetch("/encode", {
        method: "POST",
            body: formData.get("to_send")
        })
    .then(response => response.text())
    .catch(error => {
        console.error("Error:", error);
    });
});
