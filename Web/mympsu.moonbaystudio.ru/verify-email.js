(function () {
  var VERIFY_ENDPOINT = "https://api.mympsu.moonbaystudio.ru/auth/contact-email/verify";

  var statusMessage = document.getElementById("verifyStatusMessage");
  var statusTitle = document.getElementById("verifyStatusTitle");
  var statusDetails = document.getElementById("verifyStatusDetails");
  var statusCard = document.getElementById("verifyStatusCard");

  function setStatus(type, message, details) {
    if (statusMessage) {
      statusMessage.textContent = message;
      statusMessage.classList.remove("is-error", "is-success");

      if (type === "success") {
        statusMessage.classList.add("is-success");
      }

      if (type === "error") {
        statusMessage.classList.add("is-error");
      }
    }

    if (statusTitle) {
      statusTitle.textContent = message;
    }

    if (statusDetails) {
      statusDetails.textContent = details;
    }

    if (statusCard) {
      statusCard.setAttribute("data-state", type);
      statusCard.setAttribute("aria-busy", type === "loading" ? "true" : "false");
    }
  }

  function getToken() {
    var params = new URLSearchParams(window.location.search);
    var token = params.get("token");
    return typeof token === "string" ? token.trim() : "";
  }

  function isInvalidTokenStatus(status) {
    return status >= 400 && status < 500 && status !== 429;
  }

  async function verifyEmail() {
    var token = getToken();

    if (!token) {
      setStatus(
        "error",
        "Ссылка недействительна или устарела.",
        "Откройте письмо с подтверждением заново или запросите новую ссылку в приложении."
      );
      return;
    }

    setStatus(
      "loading",
      "Подтверждаем почту...",
      "Это займёт несколько секунд. Не закрывайте страницу, пока идёт проверка."
    );

    try {
      var response = await fetch(VERIFY_ENDPOINT + "?token=" + encodeURIComponent(token), {
        method: "GET",
        cache: "no-store",
        referrerPolicy: "no-referrer",
        headers: {
          Accept: "application/json"
        }
      });

      if (response.ok) {
        setStatus(
          "success",
          "Почта подтверждена. Можно вернуться в приложение Мой МПГУ.",
          "Готово: адрес привязан к вашему аккаунту."
        );
        return;
      }

      if (isInvalidTokenStatus(response.status)) {
        setStatus(
          "error",
          "Ссылка недействительна или устарела.",
          "Запросите новое письмо с подтверждением в приложении Мой МПГУ."
        );
        return;
      }

      setStatus(
        "error",
        "Не удалось подтвердить почту. Попробуйте позже.",
        "Сервис временно недоступен. Вернитесь к этой ссылке немного позже."
      );
    } catch {
      setStatus(
        "error",
        "Не удалось подтвердить почту. Попробуйте позже.",
        "Проверьте подключение к интернету и попробуйте открыть ссылку ещё раз."
      );
    }
  }

  verifyEmail();
})();
