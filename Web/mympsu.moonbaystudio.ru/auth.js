(function () {
  var API_BASE = "https://api.mympsu.moonbaystudio.ru";
  var TOKEN_KEY = "mympsu_auth_token";
  var APPLE_CLIENT_CONFIG = {
    clientId: "ru.moonbaystudio.mympsu.web",
    scope: "name email",
    redirectURI: "https://mympsu.moonbaystudio.ru/account/",
    usePopup: true
  };
  var GOOGLE_CLIENT_ID = "295307918338-v06h8kfncsi65plqte80laqe7rqj4vt4.apps.googleusercontent.com";
  var isAppleInitialized = false;
  var isGoogleInitialized = false;
  var googleCredentialCallback = null;

  function setCookie(name, value, days) {
    var expires = "";
    if (days) {
      var date = new Date();
      date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
      expires = "; expires=" + date.toUTCString();
    }
    document.cookie = name + "=" + (value || "") + expires + "; path=/; SameSite=Lax";
  }

  function getCookie(name) {
    var nameEQ = name + "=";
    var ca = document.cookie.split(';');
    for (var i = 0; i < ca.length; i++) {
      var c = ca[i];
      while (c.charAt(0) == ' ') c = c.substring(1, c.length);
      if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length, c.length);
    }
    return null;
  }

  function eraseCookie(name) {
    document.cookie = name + '=; Max-Age=-99999999; path=/; SameSite=Lax';
  }

  function saveToken(token) {
    if (typeof token !== "string" || !token.trim()) {
      return;
    }
    localStorage.setItem(TOKEN_KEY, token);
    setCookie(TOKEN_KEY, token, 30);
  }

  function getToken() {
    var token = localStorage.getItem(TOKEN_KEY) || getCookie(TOKEN_KEY);
    if (token) {
      // Sync both storages
      if (!localStorage.getItem(TOKEN_KEY)) localStorage.setItem(TOKEN_KEY, token);
      if (!getCookie(TOKEN_KEY)) setCookie(TOKEN_KEY, token, 30);
    }
    return token;
  }

  function logout() {
    localStorage.removeItem(TOKEN_KEY);
    eraseCookie(TOKEN_KEY);
  }

  function getTokenFromResponse(data) {
    if (!data || typeof data !== "object") {
      return "";
    }

    if (typeof data.token === "string") {
      return data.token;
    }
    if (typeof data.accessToken === "string") {
      return data.accessToken;
    }
    if (typeof data.access_token === "string") {
      return data.access_token;
    }
    if (data.session && typeof data.session.token === "string") {
      return data.session.token;
    }
    if (data.auth && typeof data.auth.token === "string") {
      return data.auth.token;
    }
    if (data.data) {
      return getTokenFromResponse(data.data);
    }

    return "";
  }

  function saveAuthResponse(data) {
    var token = getTokenFromResponse(data);
    if (!token) {
      throw new Error("invalid_auth_response");
    }

    saveToken(token);
  }

  function getUserFromResponse(data) {
    if (!data || typeof data !== "object") {
      return null;
    }
    if (data.user) {
      return data.user;
    }
    if (data.profile) {
      return data.profile;
    }
    if (data.data) {
      return getUserFromResponse(data.data);
    }
    return null;
  }

  function createAuthError(status, data) {
    var error = new Error("request_failed");
    error.status = status;
    error.data = data;
    return error;
  }

  async function readJson(response) {
    var text = await response.text();
    if (!text) {
      return null;
    }

    try {
      return JSON.parse(text);
    } catch (error) {
      return {
        message: text
      };
    }
  }

  async function requestJson(path, payload) {
    var response = await fetch(API_BASE + path, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify(payload)
    });
    var data = await readJson(response);

    if (!response.ok) {
      var error = new Error("request_failed");
      error.status = response.status;
      error.data = data;
      throw error;
    }

    return data;
  }

  async function requestAuthorizedJson(path, options) {
    var token = getToken();
    var requestOptions = options || {};
    var headers = {
      Authorization: "Bearer " + token
    };

    if (!token) {
      throw createAuthError(401, { detail: "Unauthorized" });
    }

    if (requestOptions.body !== undefined) {
      headers["Content-Type"] = "application/json";
    }

    var response = await fetch(API_BASE + path, {
      method: requestOptions.method || "GET",
      headers: headers,
      body: requestOptions.body !== undefined ? JSON.stringify(requestOptions.body) : undefined
    });
    var data = await readJson(response);

    if (response.status === 401) {
      logout();
    }

    if (!response.ok) {
      throw createAuthError(response.status, data);
    }

    return data;
  }

  async function authenticateWithCandidates(paths, payload) {
    var lastMissingError = null;

    for (var i = 0; i < paths.length; i += 1) {
      try {
        var data = await requestJson(paths[i], payload);
        saveAuthResponse(data);
        return data;
      } catch (error) {
        if (error.status === 404 || error.status === 405) {
          lastMissingError = error;
          continue;
        }
        throw error;
      }
    }

    var missingError = lastMissingError || new Error("auth_endpoint_missing");
    missingError.code = "auth_endpoint_missing";
    throw missingError;
  }

  function getAuthErrorMessage(error, messages) {
    if (error && error.code === "auth_endpoint_missing") {
      return messages.endpointMissing;
    }
    if (error && (error.status === 401 || error.status === 403)) {
      return messages.unauthorized;
    }
    if (error && error.status === 409) {
      return messages.conflict || messages.fallback;
    }
    if (error && error.status === 422) {
      return messages.validation;
    }

    return messages.fallback;
  }

  function getAppleAuthApi() {
    if (
      typeof window.AppleID === "undefined" ||
      !window.AppleID ||
      !window.AppleID.auth ||
      typeof window.AppleID.auth.init !== "function"
    ) {
      return null;
    }

    return window.AppleID.auth;
  }

  function isAppleAuthAvailable() {
    return !!getAppleAuthApi();
  }

  function initAppleAuth() {
    var appleAuthApi = getAppleAuthApi();

    if (!appleAuthApi) {
      return false;
    }

    if (!isAppleInitialized) {
      appleAuthApi.init({
        clientId: APPLE_CLIENT_CONFIG.clientId,
        scope: APPLE_CLIENT_CONFIG.scope,
        redirectURI: APPLE_CLIENT_CONFIG.redirectURI,
        usePopup: APPLE_CLIENT_CONFIG.usePopup
      });
      isAppleInitialized = true;
    }

    return true;
  }

  async function handleAppleCredential(identityToken, profileData) {
    if (typeof identityToken !== "string" || !identityToken.trim()) {
      throw new Error("invalid_identity_token");
    }

    var payload = {
      identityToken: identityToken
    };

    if (profileData && typeof profileData.fullName === "string" && profileData.fullName.trim()) {
      payload.fullName = profileData.fullName.trim();
    }

    if (profileData && typeof profileData.email === "string" && profileData.email.trim()) {
      payload.email = profileData.email.trim();
    }

    var response = await fetch(API_BASE + "/auth/apple", {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      throw new Error("auth_failed");
    }

    var data = await response.json();
    saveAuthResponse(data);
    return data;
  }

  async function handleGoogleCredential(credential) {
    if (typeof credential !== "string" || !credential.trim()) {
      throw new Error("invalid_google_credential");
    }

    var payload = {
      idToken: credential
    };

    var response = await fetch(API_BASE + "/auth/google", {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      throw new Error("auth_failed");
    }

    var data = await response.json();
    saveAuthResponse(data);
    return data;
  }

  async function loginWithEmail(email, password) {
    var cleanEmail = typeof email === "string" ? email.trim() : "";
    var cleanPassword = typeof password === "string" ? password : "";

    if (!cleanEmail || !cleanPassword) {
      return {
        ok: false,
        message: "Введите почту и пароль."
      };
    }

    try {
      var data = await authenticateWithCandidates(
        [
          "/auth/email/login",
          "/auth/password/login",
          "/auth/sign-in",
          "/auth/login"
        ],
        {
          email: cleanEmail,
          password: cleanPassword
        }
      );
      var user = getUserFromResponse(data) || await fetchCurrentUser();

      return {
        ok: true,
        message: "Вход выполнен.",
        user: user
      };
    } catch (error) {
      console.error(error);
      return {
        ok: false,
        message: getAuthErrorMessage(error, {
          endpointMissing: "Вход по почте и паролю пока не подключён на API.",
          unauthorized: "Неверная почта или пароль.",
          validation: "Проверьте почту и пароль.",
          fallback: "Не удалось выполнить вход. Попробуйте позже."
        })
      };
    }
  }

  async function registerWithEmail(displayName, email, password) {
    var cleanName = typeof displayName === "string" ? displayName.trim() : "";
    var cleanEmail = typeof email === "string" ? email.trim() : "";
    var cleanPassword = typeof password === "string" ? password : "";

    if (!cleanEmail || !cleanPassword) {
      return {
        ok: false,
        message: "Введите почту и пароль для регистрации."
      };
    }

    try {
      var data = await authenticateWithCandidates(
        [
          "/auth/email/register",
          "/auth/password/register",
          "/auth/sign-up",
          "/auth/register"
        ],
        {
          displayName: cleanName,
          fullName: cleanName,
          email: cleanEmail,
          password: cleanPassword
        }
      );
      var user = getUserFromResponse(data) || await fetchCurrentUser();

      return {
        ok: true,
        message: "Аккаунт создан. Вход выполнен.",
        user: user
      };
    } catch (error) {
      console.error(error);
      return {
        ok: false,
        message: getAuthErrorMessage(error, {
          endpointMissing: "Регистрация по почте и паролю пока не подключена на API.",
          unauthorized: "Не удалось зарегистрироваться с этими данными.",
          conflict: "Аккаунт с такой почтой уже существует.",
          validation: "Проверьте почту и пароль.",
          fallback: "Не удалось создать аккаунт. Попробуйте позже."
        })
      };
    }
  }

  async function fetchCurrentUser() {
    if (!getToken()) {
      return null;
    }

    var data = await requestAuthorizedJson("/me");
    return data && data.user ? data.user : data;
  }

  function updateProfileName(name) {
    return requestAuthorizedJson("/me", {
      method: "PATCH",
      body: {
        name: name
      }
    });
  }

  function requestEmailChange(email) {
    return requestAuthorizedJson("/me/email/change-request", {
      method: "POST",
      body: {
        email: email
      }
    });
  }

  function confirmEmailChange(code) {
    return requestAuthorizedJson("/me/email/confirm", {
      method: "POST",
      body: {
        code: code
      }
    });
  }

  function createPassword(password) {
    return requestAuthorizedJson("/me/password/create", {
      method: "POST",
      body: {
        password: password
      }
    });
  }

  function changePassword(currentPassword, newPassword) {
    return requestAuthorizedJson("/me/password/change", {
      method: "POST",
      body: {
        currentPassword: currentPassword,
        newPassword: newPassword
      }
    });
  }

  function getSettings() {
    return requestAuthorizedJson("/settings");
  }

  function updateSettings(settings) {
    return requestAuthorizedJson("/settings", {
      method: "PUT",
      body: settings
    });
  }

  async function loginWithApple() {
    if (!initAppleAuth()) {
      return {
        ok: false,
        message: "Apple Login временно недоступен. Попробуйте позже."
      };
    }

    try {
      var response = await window.AppleID.auth.signIn();
      var identityToken = response && response.authorization && response.authorization.id_token;

      if (typeof identityToken !== "string" || !identityToken.trim()) {
        throw new Error("missing_identity_token");
      }

      var appleUser = response && response.user ? response.user : null;
      var firstName = appleUser && appleUser.name ? appleUser.name.firstName : "";
      var lastName = appleUser && appleUser.name ? appleUser.name.lastName : "";
      var fullName = [firstName, lastName].filter(Boolean).join(" ").trim();
      var email = appleUser && appleUser.email ? appleUser.email : "";

      var data = await handleAppleCredential(identityToken, {
        fullName: fullName,
        email: email
      });

      var user = getUserFromResponse(data) || await fetchCurrentUser();

      return {
        ok: true,
        message: "Вход выполнен.",
        user: user
      };
    } catch (error) {
      console.error(error);
      var code = error && error.error ? error.error : "";
      var message = error && error.message ? String(error.message) : "";
      if (
        code === "user_cancelled_authorize" ||
        code === "popup_closed_by_user" ||
        message.indexOf("popup_closed_by_user") !== -1 ||
        message.indexOf("user_cancelled_authorize") !== -1
      ) {
        return {
          ok: false,
          message: "Вход отменён пользователем."
        };
      }

      return {
        ok: false,
        message: "Не удалось выполнить вход через Apple. Попробуйте позже."
      };
    }
  }

  function getGoogleIdApi() {
    if (
      typeof window.google === "undefined" ||
      !window.google.accounts ||
      !window.google.accounts.id
    ) {
      return null;
    }

    return window.google.accounts.id;
  }

  function isGoogleAuthAvailable() {
    return !!getGoogleIdApi();
  }

  function initGoogleAuth(callback) {
    var googleIdApi = getGoogleIdApi();

    if (!googleIdApi) {
      return false;
    }

    googleCredentialCallback = typeof callback === "function" ? callback : null;

    if (!isGoogleInitialized) {
      googleIdApi.initialize({
        client_id: GOOGLE_CLIENT_ID,
        callback: function (response) {
          if (typeof googleCredentialCallback === "function") {
            googleCredentialCallback(response);
          }
        },
        auto_select: false
      });
      isGoogleInitialized = true;
    }

    return true;
  }

  function renderGoogleButton(container, callback, options) {
    if (!container || !initGoogleAuth(callback)) {
      return false;
    }

    var googleIdApi = getGoogleIdApi();
    var rect = typeof container.getBoundingClientRect === "function" ? container.getBoundingClientRect() : null;
    var width = rect && rect.width ? Math.floor(rect.width) : 320;

    if (width < 220) {
      width = 320;
    }

    container.innerHTML = "";
    container.classList.remove("is-disabled");
    container.setAttribute("aria-disabled", "false");

    try {
      googleIdApi.renderButton(container, {
        type: "standard",
        theme: "outline",
        size: "large",
        text: options && options.text ? options.text : "signin_with",
        shape: "pill",
        logo_alignment: "left",
        width: Math.min(width, 400)
      });
    } catch (error) {
      console.error(error);
      return false;
    }

    return true;
  }

  async function loginWithGoogle() {
    return new Promise(function (resolve) {
      var initialized = initGoogleAuth(async function (response) {
        try {
          var data = await handleGoogleCredential(response.credential);
          var user = getUserFromResponse(data) || await fetchCurrentUser();
          resolve({
            ok: true,
            message: "Вход выполнен.",
            user: user
          });
        } catch (error) {
          console.error(error);
          resolve({
            ok: false,
            message: "Не удалось выполнить вход через Google."
          });
        }
      });

      if (!initialized) {
        resolve({
          ok: false,
          message: "Google Login временно недоступен."
        });
        return;
      }

      var googleIdApi = getGoogleIdApi();
      googleIdApi.prompt(function (notification) {
        if (
          notification &&
          (
            notification.isNotDisplayed && notification.isNotDisplayed() ||
            notification.isSkippedMoment && notification.isSkippedMoment()
          )
        ) {
          resolve({
            ok: false,
            message: "Google Login не открылся. Используйте кнопку Google на странице."
          });
        }
      });
    });
  }

  window.MyMPSUAuth = {
    initAppleAuth: initAppleAuth,
    isAppleAuthAvailable: isAppleAuthAvailable,
    initGoogleAuth: initGoogleAuth,
    isGoogleAuthAvailable: isGoogleAuthAvailable,
    renderGoogleButton: renderGoogleButton,
    loginWithApple: loginWithApple,
    loginWithGoogle: loginWithGoogle,
    loginWithEmail: loginWithEmail,
    registerWithEmail: registerWithEmail,
    handleAppleCredential: handleAppleCredential,
    handleGoogleCredential: handleGoogleCredential,
    getUserFromResponse: getUserFromResponse,
    requestAuthorizedJson: requestAuthorizedJson,
    updateProfileName: updateProfileName,
    requestEmailChange: requestEmailChange,
    confirmEmailChange: confirmEmailChange,
    createPassword: createPassword,
    changePassword: changePassword,
    getSettings: getSettings,
    updateSettings: updateSettings,
    saveToken: saveToken,
    getToken: getToken,
    logout: logout,
    fetchCurrentUser: fetchCurrentUser
  };
})();
