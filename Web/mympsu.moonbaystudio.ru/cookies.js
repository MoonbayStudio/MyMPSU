(function () {
  var KEY = "moonbay_cookie_consent_v1";
  var defaults = { necessary: true, analytics: false, marketing: false };

  function readConsent() {
    try {
      var raw = localStorage.getItem(KEY);
      return raw ? JSON.parse(raw) : null;
    } catch (error) {
      return null;
    }
  }

  function saveConsent(settings) {
    var payload = {
      necessary: true,
      analytics: Boolean(settings.analytics),
      marketing: Boolean(settings.marketing),
      updatedAt: new Date().toISOString()
    };

    try {
      localStorage.setItem(KEY, JSON.stringify(payload));
    } catch (error) {}

    window.MoonbayCookieConsent = payload;
    return payload;
  }

  function createButton(text, className, onClick) {
    var button = document.createElement("button");
    button.type = "button";
    button.className = className;
    button.textContent = text;
    button.addEventListener("click", onClick);
    return button;
  }

  function init() {
    if (document.querySelector(".cookie-banner")) {
      return;
    }

    var saved = readConsent();
    window.MoonbayCookieConsent = saved || defaults;

    var banner = document.createElement("section");
    banner.className = "cookie-banner";
    banner.setAttribute("aria-label", "Уведомление об использовании cookie");
    banner.innerHTML =
      '<div class="cookie-banner-inner">' +
        '<div><h2>Мы используем cookie</h2>' +
        '<p>Необходимые cookie помогают сайту работать. Аналитика и маркетинг сейчас не подключены и могут использоваться только после обновления политики и вашего согласия.</p></div>' +
        '<div class="cookie-actions"></div>' +
      '</div>';

    var modal = document.createElement("section");
    modal.className = "cookie-modal";
    modal.setAttribute("aria-hidden", "true");
    modal.innerHTML =
      '<div class="cookie-modal-panel" role="dialog" aria-modal="true" aria-labelledby="cookieSettingsTitle">' +
        '<div class="cookie-modal-head">' +
          '<div><h2 id="cookieSettingsTitle">Настройки Cookie</h2>' +
          '<p>Выберите, какие категории cookie можно использовать на этом сайте.</p></div>' +
          '<button type="button" class="cookie-close" aria-label="Закрыть">×</button>' +
        '</div>' +
        '<div class="cookie-options">' +
          '<label class="cookie-option"><span><strong>Необходимые cookie</strong><p>Нужны для безопасности, навигации и сохранения выбранных настроек. Всегда активны.</p></span><input type="checkbox" checked disabled></label>' +
          '<label class="cookie-option"><span><strong>Аналитика</strong><p>Сейчас аналитические скрипты не подключены. Этот выбор будет учитываться, если аналитика появится позже.</p></span><input type="checkbox" data-cookie-input="analytics"></label>' +
          '<label class="cookie-option"><span><strong>Маркетинг</strong><p>Сейчас рекламные и маркетинговые трекеры не подключены. Этот выбор будет учитываться, если они появятся позже.</p></span><input type="checkbox" data-cookie-input="marketing"></label>' +
        '</div>' +
        '<div class="cookie-actions"></div>' +
      '</div>';

    document.body.appendChild(banner);
    document.body.appendChild(modal);

    var bannerActions = banner.querySelector(".cookie-actions");
    var modalActions = modal.querySelector(".cookie-actions");
    var analyticsInput = modal.querySelector('[data-cookie-input="analytics"]');
    var marketingInput = modal.querySelector('[data-cookie-input="marketing"]');

    function syncInputs() {
      var current = readConsent() || defaults;
      analyticsInput.checked = Boolean(current.analytics);
      marketingInput.checked = Boolean(current.marketing);
    }

    function hideBanner() {
      banner.classList.remove("is-visible");
    }

    function openSettings() {
      syncInputs();
      modal.classList.add("is-visible");
      modal.setAttribute("aria-hidden", "false");
    }

    function closeSettings() {
      modal.classList.remove("is-visible");
      modal.setAttribute("aria-hidden", "true");
    }

    function saveSelected() {
      saveConsent({
        analytics: analyticsInput.checked,
        marketing: marketingInput.checked
      });
      hideBanner();
      closeSettings();
    }

    function acceptAll() {
      saveConsent({ analytics: true, marketing: true });
      hideBanner();
      closeSettings();
    }

    function necessaryOnly() {
      saveConsent({ analytics: false, marketing: false });
      hideBanner();
      closeSettings();
    }

    bannerActions.appendChild(createButton("Настроить", "button secondary", openSettings));
    bannerActions.appendChild(createButton("Только необходимые", "button secondary", necessaryOnly));
    bannerActions.appendChild(createButton("Разрешить все", "button primary", acceptAll));

    modalActions.appendChild(createButton("Сохранить выбор", "button primary", saveSelected));
    modalActions.appendChild(createButton("Разрешить все", "button secondary", acceptAll));
    modalActions.appendChild(createButton("Только необходимые", "button secondary", necessaryOnly));

    modal.querySelector(".cookie-close").addEventListener("click", closeSettings);
    modal.addEventListener("click", function (event) {
      if (event.target === modal) {
        closeSettings();
      }
    });

    document.addEventListener("click", function (event) {
      var trigger = event.target.closest("[data-cookie-settings]");
      if (trigger) {
        event.preventDefault();
        openSettings();
      }
    });

    if (!saved) {
      banner.classList.add("is-visible");
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
