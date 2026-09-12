(function () {
  var auth = window.MyMPSUAuth;
  if (!auth) {
    return;
  }

  var messageEl = document.getElementById("authMessage");
  var loggedOutStateEl = document.getElementById("loggedOutState");
  var loggedInStateEl = document.getElementById("loggedInState");
  var loginForm = document.getElementById("loginForm");
  var registerForm = document.getElementById("registerForm");
  var loginAppleButton = document.getElementById("loginAppleButton");
  var registerAppleButton = document.getElementById("registerAppleButton");
  var loginGoogleButton = document.getElementById("loginGoogleButton");
  var registerGoogleButton = document.getElementById("registerGoogleButton");

  var loginEmailEl = document.getElementById("loginEmail");
  var loginPasswordEl = document.getElementById("loginPassword");
  var registerNameEl = document.getElementById("registerName");
  var registerEmailEl = document.getElementById("registerEmail");
  var registerPasswordEl = document.getElementById("registerPassword");

  var displayNameEl = document.getElementById("profileDisplayName");
  var emailEl = document.getElementById("profileEmail");
  var userIdEl = document.getElementById("profileUserId");
  var tierEl = document.getElementById("profileTier");
  var remainingTodayEl = document.getElementById("profileRemainingToday");
  var emailVerifiedEl = document.getElementById("profileEmailVerified");
  var providersEl = document.getElementById("profileProviders");
  var rolesEl = document.getElementById("profileRoles");
  var badgesEl = document.getElementById("profileBadges");
  var profileNameForm = document.getElementById("profileNameForm");
  var profileNameInput = document.getElementById("profileNameInput");
  var emailChangeForm = document.getElementById("emailChangeForm");
  var newEmailInput = document.getElementById("newEmailInput");
  var emailConfirmForm = document.getElementById("emailConfirmForm");
  var emailCodeInput = document.getElementById("emailCodeInput");
  var emailPendingNote = document.getElementById("emailPendingNote");
  var passwordForm = document.getElementById("passwordForm");
  var passwordPanelTitle = document.getElementById("passwordPanelTitle");
  var currentPasswordLabel = document.getElementById("currentPasswordLabel");
  var currentPasswordInput = document.getElementById("currentPasswordInput");
  var newPasswordLabelText = document.getElementById("newPasswordLabelText");
  var newPasswordInput = document.getElementById("newPasswordInput");
  var passwordSubmitButton = document.getElementById("passwordSubmitButton");

  var currentUser = null;
  var currentSettings = null;

  function setMessage(text, type) {
    if (!messageEl) {
      return;
    }

    messageEl.textContent = text;
    messageEl.className = "auth-message";
    messageEl.hidden = !text;

    if (type === "error") {
      messageEl.classList.add("is-error");
    } else if (type === "success") {
      messageEl.classList.add("is-success");
    }
  }

  function updateNav() {
    if (
      window.MyMPSUNav &&
      typeof window.MyMPSUNav.updateAuthNav === "function"
    ) {
      window.MyMPSUNav.updateAuthNav();
    }
  }

  function setLoading(button, isLoading, loadingText) {
    if (!button) {
      return;
    }

    if (isLoading) {
      button.dataset.defaultText = button.textContent;
      button.textContent = loadingText;
      button.disabled = true;
      return;
    }

    button.textContent = button.dataset.defaultText || button.textContent;
    button.disabled = false;
  }

  function setAppleButtonsDisabled(disabled) {
    [loginAppleButton, registerAppleButton].forEach(function (button) {
      if (button) {
        button.disabled = disabled;
      }
    });
  }

  function setGoogleButtonsDisabled(disabled) {
    [loginGoogleButton, registerGoogleButton].forEach(function (button) {
      if (button) {
        if ("disabled" in button) {
          button.disabled = disabled;
        }
        var fallbackButton = button.querySelector ? button.querySelector("button") : null;
        if (fallbackButton) {
          fallbackButton.disabled = disabled;
        }
        button.classList.toggle("is-disabled", disabled);
        button.setAttribute("aria-disabled", disabled ? "true" : "false");
      }
    });
  }

  function setGoogleSlotFallback(slot, label, disabled) {
    if (!slot) {
      return;
    }

    slot.innerHTML = "";
    slot.classList.toggle("is-disabled", !!disabled);
    slot.setAttribute("aria-disabled", disabled ? "true" : "false");

    var button = document.createElement("button");
    button.type = "button";
    button.className = "button secondary google-button google-fallback-button";
    button.textContent = label;
    button.disabled = !!disabled;
    button.addEventListener("click", function () {
      handleGoogleLogin(button);
    });

    slot.appendChild(button);
  }

  async function handleGoogleCredentialResponse(response) {
    try {
      if (!response || typeof response.credential !== "string") {
        throw new Error("missing_google_credential");
      }

      setGoogleButtonsDisabled(true);
      setMessage("Выполняем вход через Google...");
      var data = await auth.handleGoogleCredential(response.credential);
      var user = auth.getUserFromResponse(data) || await auth.fetchCurrentUser();
      renderLoggedIn(user);
    } catch (error) {
      console.error(error);
      setMessage("Не удалось войти через Google.", "error");
    } finally {
      setGoogleButtonsDisabled(false);
    }
  }

  function renderGoogleSlot(slot, options) {
    if (!slot) {
      return true;
    }

    var fallbackLabel = options && options.fallbackLabel ? options.fallbackLabel : "Войти через Google";
    var loadingLabel = slot.dataset.loadingLabel || "Google Login загружается...";

    setGoogleSlotFallback(slot, loadingLabel, true);

    if (
      typeof auth.renderGoogleButton !== "function" ||
      typeof auth.isGoogleAuthAvailable !== "function" ||
      !auth.isGoogleAuthAvailable()
    ) {
      setGoogleSlotFallback(slot, fallbackLabel, false);
      return false;
    }

    var rendered = auth.renderGoogleButton(
      slot,
      handleGoogleCredentialResponse,
      { text: options && options.text ? options.text : "signin_with" }
    );

    if (!rendered) {
      setGoogleSlotFallback(slot, fallbackLabel, false);
      return false;
    }

    window.setTimeout(function () {
      if (slot.children.length === 0) {
        setGoogleSlotFallback(slot, fallbackLabel, false);
      }
    }, 1200);

    return true;
  }

  function renderGoogleButtons() {
    var loginReady = renderGoogleSlot(loginGoogleButton, {
      text: "signin_with",
      fallbackLabel: "Войти через Google"
    });
    var registerReady = renderGoogleSlot(registerGoogleButton, {
      text: "signup_with",
      fallbackLabel: "Зарегистрироваться через Google"
    });

    return loginReady && registerReady;
  }

  function valueOrDash(value) {
    if (value === null || value === undefined || value === "") {
      return "—";
    }
    return String(value);
  }

  function setText(element, value) {
    if (element) {
      element.textContent = valueOrDash(value);
    }
  }

  function getErrorDetail(error, fallback) {
    var data = error && error.data ? error.data : null;
    if (data && typeof data.detail === "string") {
      return data.detail;
    }
    if (data && typeof data.message === "string") {
      return data.message;
    }
    return fallback;
  }

  function clearElement(element) {
    if (element) {
      element.innerHTML = "";
    }
  }

  function appendChip(container, text, variant) {
    if (!container) {
      return;
    }

    var chip = document.createElement("span");
    chip.className = "profile-chip";
    if (variant) {
      chip.classList.add("profile-chip-" + variant);
    }
    chip.textContent = text;
    container.appendChild(chip);
  }

  function renderChipList(container, items, emptyText, formatter, variant) {
    clearElement(container);

    if (!container) {
      return;
    }

    if (!items || !items.length) {
      appendChip(container, emptyText, "muted");
      return;
    }

    items.forEach(function (item) {
      appendChip(container, formatter ? formatter(item) : String(item), variant);
    });
  }

  function renderProviders(user) {
    var linked = user && Array.isArray(user.linkedProviders) ? user.linkedProviders : [];
    var providers = [
      { id: "apple", title: "Apple" },
      { id: "google", title: "Google" },
      { id: "password", title: user && user.hasPassword ? "Пароль задан" : "Пароль не задан" }
    ];

    clearElement(providersEl);
    providers.forEach(function (provider) {
      var isLinked = provider.id === "password" ? !!(user && user.hasPassword) : linked.indexOf(provider.id) !== -1;
      appendChip(providersEl, provider.title, isLinked ? "ok" : "muted");
    });
  }

  function renderSecurityForms(user) {
    var hasPassword = !!(user && user.hasPassword);

    if (passwordPanelTitle) {
      passwordPanelTitle.textContent = hasPassword ? "Сменить пароль" : "Создать пароль";
    }
    if (currentPasswordLabel) {
      currentPasswordLabel.hidden = !hasPassword;
    }
    if (currentPasswordInput) {
      currentPasswordInput.required = hasPassword;
      currentPasswordInput.value = "";
    }
    if (newPasswordLabelText) {
      newPasswordLabelText.textContent = hasPassword ? "Новый пароль" : "Пароль";
    }
    if (newPasswordInput) {
      newPasswordInput.value = "";
      newPasswordInput.autocomplete = hasPassword ? "new-password" : "new-password";
    }
    if (passwordSubmitButton) {
      passwordSubmitButton.textContent = hasPassword ? "Сменить пароль" : "Создать пароль";
    }
  }

  function renderRoles(user, settings) {
    var roles = user && Array.isArray(user.roles) ? user.roles.slice() : [];
    var groupName = settings && settings.selectedGroupName ? settings.selectedGroupName : "";
    var groupId = settings && settings.selectedGroupId ? settings.selectedGroupId : "";

    if (groupName || groupId) {
      roles.push({
        title: groupName ? "Группа: " + groupName : "Группа #" + groupId
      });
    }

    renderChipList(rolesEl, roles, "Ролей пока нет", function (role) {
      var title = role && role.title ? role.title : role && role.type ? role.type : "Роль";
      if (role && role.groupId && title.indexOf("Группа") !== 0) {
        return title + " #" + role.groupId;
      }
      return title;
    }, "ok");
  }

  function renderProfileDetails(user) {
    currentUser = user || null;
    if (!user) {
      currentSettings = null;
    }

    setText(displayNameEl, user && user.displayName);
    setText(emailEl, user && user.email);
    setText(userIdEl, user && user.id);
    setText(tierEl, user && user.tier);
    setText(remainingTodayEl, user && user.remainingToday === -1 ? "Без лимита" : user && user.remainingToday);
    setText(emailVerifiedEl, user && user.emailVerified ? "Подтверждена" : "Не подтверждена");

    if (profileNameInput) {
      profileNameInput.value = user && user.displayName ? user.displayName : "";
    }
    if (newEmailInput) {
      newEmailInput.value = "";
    }
    if (emailCodeInput) {
      emailCodeInput.value = "";
    }
    if (emailPendingNote) {
      emailPendingNote.textContent = user && user.pendingEmail
        ? "Ожидает подтверждения: " + user.pendingEmail
        : "Новая почта подтверждается кодом.";
    }

    renderProviders(user);
    renderSecurityForms(user);
    renderRoles(user, currentSettings);
    renderChipList(badgesEl, user && user.badges, "Значков пока нет", function (badge) {
      return badge && badge.title ? badge.title : badge && badge.code ? badge.code : "Значок";
    }, "accent");
  }

  async function loadSettings() {
    if (typeof auth.getSettings !== "function" || !auth.getToken()) {
      return;
    }

    try {
      currentSettings = await auth.getSettings();
      renderRoles(currentUser, currentSettings);
    } catch (error) {
      console.error(error);
    }
  }

  function renderLoggedOut(message, type) {
    if (loggedOutStateEl) {
      loggedOutStateEl.hidden = false;
    }
    if (loggedInStateEl) {
      loggedInStateEl.hidden = true;
    }

    renderProfileDetails(null);

    setMessage(message || "Вы не вошли в аккаунт.", type || "info");
    updateNav();
  }

  function renderLoggedIn(user) {
    renderProfileDetails(user);

    if (loggedOutStateEl) {
      loggedOutStateEl.hidden = true;
    }
    if (loggedInStateEl) {
      loggedInStateEl.hidden = false;
    }

    setMessage("");
    updateNav();
    loadSettings();
  }

  async function handleAuthResult(result, fallbackMessage) {
    if (result && result.ok) {
      if (result.user) {
        renderLoggedIn(result.user);
      } else {
        await restoreSession();
      }
      return;
    }

    setMessage(result && result.message ? result.message : fallbackMessage, "error");
  }

  async function restoreSession() {
    if (typeof auth.initAppleAuth === "function") {
      auth.initAppleAuth();
    }
    setAppleButtonsDisabled(false);

    renderGoogleButtons();

    var token = auth.getToken();
    if (!token) {
      var methods = ["почте", "регистрацию"];
      methods.push("Apple");
      methods.push("Google");

      var msg = "Выберите вход по " + methods.join(", ") + ".";
      renderLoggedOut(msg);
      return;
    }

    try {
      var user = await auth.fetchCurrentUser();
      if (user) {
        renderLoggedIn(user);
        return;
      }

      renderLoggedOut("Сессия истекла. Войдите снова.");
    } catch (error) {
      console.error(error);
      renderLoggedOut("Не удалось загрузить профиль. Попробуйте позже.", "error");
    }
  }

  async function handleAppleLogin(button) {
    try {
      setLoading(button, true, "Открываем Apple...");
      var result = await auth.loginWithApple();
      await handleAuthResult(result, "Не удалось выполнить вход через Apple.");
    } catch (error) {
      console.error(error);
      setMessage("Не удалось начать вход через Apple. Попробуйте позже.", "error");
    } finally {
      setLoading(button, false);
    }
  }

  async function handleGoogleLogin(button) {
    try {
      setLoading(button, true, "Открываем Google...");
      var result = await auth.loginWithGoogle();
      await handleAuthResult(result, "Не удалось выполнить вход через Google.");
    } catch (error) {
      console.error(error);
      setMessage("Не удалось начать вход через Google.", "error");
    } finally {
      setLoading(button, false);
    }
  }

  if (loginForm) {
    loginForm.addEventListener("submit", async function (event) {
      event.preventDefault();
      var submitButton = loginForm.querySelector('button[type="submit"]');

      try {
        setLoading(submitButton, true, "Входим...");
        var result = await auth.loginWithEmail(loginEmailEl.value, loginPasswordEl.value);
        await handleAuthResult(result, "Не удалось выполнить вход.");
      } finally {
        setLoading(submitButton, false);
      }
    });
  }

  if (registerForm) {
    registerForm.addEventListener("submit", async function (event) {
      event.preventDefault();
      var submitButton = registerForm.querySelector('button[type="submit"]');

      try {
        setLoading(submitButton, true, "Создаём...");
        var result = await auth.registerWithEmail(
          registerNameEl.value,
          registerEmailEl.value,
          registerPasswordEl.value
        );
        await handleAuthResult(result, "Не удалось создать аккаунт.");
      } finally {
        setLoading(submitButton, false);
      }
    });
  }

  if (profileNameForm) {
    profileNameForm.addEventListener("submit", async function (event) {
      event.preventDefault();
      var submitButton = profileNameForm.querySelector('button[type="submit"]');

      try {
        setLoading(submitButton, true, "Сохраняем...");
        var user = await auth.updateProfileName(profileNameInput.value);
        renderLoggedIn(user);
        setMessage("Имя обновлено.", "success");
      } catch (error) {
        console.error(error);
        setMessage(getErrorDetail(error, "Не удалось сохранить имя."), "error");
      } finally {
        setLoading(submitButton, false);
      }
    });
  }

  if (emailChangeForm) {
    emailChangeForm.addEventListener("submit", async function (event) {
      event.preventDefault();
      var submitButton = emailChangeForm.querySelector('button[type="submit"]');

      try {
        setLoading(submitButton, true, "Отправляем...");
        await auth.requestEmailChange(newEmailInput.value);
        if (emailPendingNote) {
          emailPendingNote.textContent = "Код отправлен на " + newEmailInput.value.trim() + ".";
        }
        setMessage("Код подтверждения отправлен.", "success");
      } catch (error) {
        console.error(error);
        setMessage(getErrorDetail(error, "Не удалось отправить код подтверждения."), "error");
      } finally {
        setLoading(submitButton, false);
      }
    });
  }

  if (emailConfirmForm) {
    emailConfirmForm.addEventListener("submit", async function (event) {
      event.preventDefault();
      var submitButton = emailConfirmForm.querySelector('button[type="submit"]');

      try {
        setLoading(submitButton, true, "Проверяем...");
        var user = await auth.confirmEmailChange(emailCodeInput.value);
        renderLoggedIn(user);
        setMessage("Почта обновлена.", "success");
      } catch (error) {
        console.error(error);
        setMessage(getErrorDetail(error, "Не удалось подтвердить почту."), "error");
      } finally {
        setLoading(submitButton, false);
      }
    });
  }

  if (passwordForm) {
    passwordForm.addEventListener("submit", async function (event) {
      event.preventDefault();
      var submitButton = passwordForm.querySelector('button[type="submit"]');

      try {
        setLoading(submitButton, true, "Сохраняем...");
        if (currentUser && currentUser.hasPassword) {
          await auth.changePassword(currentPasswordInput.value, newPasswordInput.value);
        } else {
          await auth.createPassword(newPasswordInput.value);
        }

        var user = await auth.fetchCurrentUser();
        renderLoggedIn(user);
        setMessage("Пароль сохранён.", "success");
      } catch (error) {
        console.error(error);
        setMessage(getErrorDetail(error, "Не удалось сохранить пароль."), "error");
      } finally {
        setLoading(submitButton, false);
      }
    });
  }

  if (loginAppleButton) {
    loginAppleButton.addEventListener("click", function () {
      handleAppleLogin(loginAppleButton);
    });
  }

  if (registerAppleButton) {
    registerAppleButton.addEventListener("click", function () {
      handleAppleLogin(registerAppleButton);
    });
  }

  window.addEventListener("mympsu:logout", function () {
    renderLoggedOut("Вы вышли из аккаунта.", "success");
  });

  restoreSession();

  if (
    typeof auth.isGoogleAuthAvailable === "function" &&
    typeof auth.isAppleAuthAvailable === "function" &&
    (!auth.isGoogleAuthAvailable() || !auth.isAppleAuthAvailable())
  ) {
    var providerLoadAttempts = 0;
    var providerLoadTimer = window.setInterval(function () {
      providerLoadAttempts += 1;

      if (
        (auth.isGoogleAuthAvailable() && auth.isAppleAuthAvailable()) ||
        providerLoadAttempts >= 20
      ) {
        window.clearInterval(providerLoadTimer);
        restoreSession();
      }
    }, 250);
  }
})();
