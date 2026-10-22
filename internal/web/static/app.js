(() => {
  // Confirm destructive forms.
  document.querySelectorAll("form[data-confirm]").forEach((form) => {
    form.addEventListener("submit", (event) => {
      const message = form.getAttribute("data-confirm") || "确定要执行此操作吗？";
      if (!window.confirm(message)) {
        event.preventDefault();
      }
    });
  });

  // Copy-to-clipboard buttons.
  document.querySelectorAll("[data-copy]").forEach((button) => {
    button.addEventListener("click", async () => {
      const value = button.getAttribute("data-copy") || "";
      try {
        await navigator.clipboard.writeText(value);
      } catch (_) {
        const area = document.createElement("textarea");
        area.value = value;
        area.style.position = "fixed";
        area.style.opacity = "0";
        document.body.appendChild(area);
        area.select();
        document.execCommand("copy");
        area.remove();
      }
      const original = button.textContent;
      button.textContent = "已复制";
      button.disabled = true;
      window.setTimeout(() => {
        button.textContent = original;
        button.disabled = false;
      }, 1400);
    });
  });

  // All-day events use date inputs instead of datetime-local inputs.
  const allDay = document.querySelector("#all-day-toggle");
  if (allDay) {
    const inputs = [
      document.querySelector('input[name="start"]'),
      document.querySelector('input[name="end"]'),
    ].filter(Boolean);
    const apply = () => {
      inputs.forEach((input) => {
        if (allDay.checked) {
          input.type = "date";
          if (input.value && input.value.includes("T")) {
            input.value = input.value.split("T")[0];
          }
        } else {
          input.type = "datetime-local";
          if (input.value && !input.value.includes("T")) {
            input.value = input.value + "T09:00";
          }
        }
      });
    };
    allDay.addEventListener("change", apply);
    apply();
  }

  // Auto-dismiss success alerts.
  document.querySelectorAll(".alert-ok").forEach((alert) => {
    window.setTimeout(() => {
      alert.style.transition = "opacity 400ms ease";
      alert.style.opacity = "0";
      window.setTimeout(() => alert.remove(), 420);
    }, 4200);
  });
})();
