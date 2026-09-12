(function () {
  var TOKEN_KEY = "mympsu_auth_token";

  function getCookie(name) {
    var nameEQ = name + "=";
    var parts = document.cookie.split(";");
    for (var i = 0; i < parts.length; i += 1) {
      var part = parts[i].trim();
      if (part.indexOf(nameEQ) === 0) {
        return part.substring(nameEQ.length);
      }
    }
    return "";
  }

  function isLoggedIn() {
    if (
      window.MyMPSUAuth &&
      typeof window.MyMPSUAuth.getToken === "function" &&
      window.MyMPSUAuth.getToken()
    ) {
      return true;
    }

    return Boolean(localStorage.getItem(TOKEN_KEY) || getCookie(TOKEN_KEY));
  }

  function setHidden(elements, hidden) {
    Array.prototype.forEach.call(elements, function (element) {
      element.hidden = hidden;
    });
  }

  function updateAuthNav() {
    var guestLinks = document.querySelectorAll('[data-auth-link="guest"]');
    var accountLinks = document.querySelectorAll('[data-auth-link="account"]');
    var loggedIn = isLoggedIn();

    setHidden(guestLinks, loggedIn);
    setHidden(accountLinks, !loggedIn);
  }

  function logout() {
    if (
      window.MyMPSUAuth &&
      typeof window.MyMPSUAuth.logout === "function"
    ) {
      window.MyMPSUAuth.logout();
    } else {
      localStorage.removeItem(TOKEN_KEY);
      document.cookie = TOKEN_KEY + "=; Max-Age=-99999999; path=/; SameSite=Lax";
    }

    updateAuthNav();
    window.dispatchEvent(new CustomEvent("mympsu:logout"));
  }

  window.MyMPSUNav = {
    updateAuthNav: updateAuthNav,
    logout: logout
  };

  document.addEventListener("DOMContentLoaded", updateAuthNav);
  window.addEventListener("load", updateAuthNav);
  window.addEventListener("pageshow", updateAuthNav);

  document.addEventListener("click", function (event) {
    var logoutButton = event.target.closest('[data-auth-action="logout"]');
    if (!logoutButton) {
      return;
    }

    event.preventDefault();
    logout();
  });

  document.addEventListener("visibilitychange", function () {
    if (!document.hidden) {
      updateAuthNav();
    }
  });

  window.addEventListener("storage", function (event) {
    if (event.key === TOKEN_KEY) {
      updateAuthNav();
    }
  });
})();
