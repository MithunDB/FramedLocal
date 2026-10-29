(() => {
  const device = document.querySelector("#demoDevice");
  const feedback = document.querySelector("#studioFeedback");
  const caption = document.querySelector("#deviceCaption");
  const lensLabel = document.querySelector("#lensLabel");
  const guidanceToggle = document.querySelector("#guidanceToggle");
  const gridToggle = document.querySelector("#gridToggle");
  const dateToggle = document.querySelector("#dateToggle");
  const shutter = document.querySelector("#shutter");
  const zoomDial = document.querySelector("#demoZoom");
  const zoomReadout = document.querySelector("#demoZoomValue");
  const zoomRuler = document.querySelector("#demoZoomRuler");
  let sampleZoom = 1;
  let zoomDragStart = null;

  for (let index = -6; index <= 12; index += 1) {
    const tick = document.createElement("i");
    tick.dataset.tick = String(index);
    if (index % 6 === 0) tick.classList.add("is-major");
    zoomRuler.append(tick);
  }

  const updateZoomDial = (requested) => {
    sampleZoom = Math.min(4, Math.max(0.5, requested));
    const position = Math.log2(sampleZoom) * 6;
    zoomReadout.textContent = `${sampleZoom.toFixed(1)}×`;
    zoomDial.setAttribute("aria-valuenow", sampleZoom.toFixed(1));
    zoomDial.setAttribute("aria-valuetext", `${sampleZoom.toFixed(1)} times`);
    device.style.setProperty("--camera-zoom", String(Math.max(0.82, 1 + (sampleZoom - 1) * 0.36)));
    zoomRuler.querySelectorAll("i").forEach((tick) => {
      const index = Number(tick.dataset.tick);
      tick.style.left = `calc(50% + ${(index - position) * 9}px)`;
      tick.classList.toggle("is-current", Math.abs(index - position) < 0.35);
    });
  };

  zoomDial.addEventListener("pointerdown", (event) => {
    zoomDragStart = { x: event.clientX, value: sampleZoom };
    zoomDial.setPointerCapture(event.pointerId);
  });
  zoomDial.addEventListener("pointermove", (event) => {
    if (!zoomDragStart) return;
    updateZoomDial(zoomDragStart.value * 2 ** ((zoomDragStart.x - event.clientX) / 140));
  });
  zoomDial.addEventListener("pointerup", () => { zoomDragStart = null; });
  zoomDial.addEventListener("pointercancel", () => { zoomDragStart = null; });
  zoomDial.addEventListener("wheel", (event) => {
    event.preventDefault();
    updateZoomDial(sampleZoom * 2 ** (-event.deltaY / 480));
  }, { passive: false });
  zoomDial.addEventListener("keydown", (event) => {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
    event.preventDefault();
    updateZoomDial(sampleZoom * 2 ** (event.key === "ArrowRight" ? 1 / 12 : -1 / 12));
  });
  updateZoomDial(sampleZoom);

  const pressButtons = (selector, selectedElement) => {
    document.querySelectorAll(selector).forEach((button) => {
      const selected = button === selectedElement;
      button.classList.toggle("is-selected", selected);
      button.classList.toggle("is-active", selected);
      button.setAttribute("aria-pressed", String(selected));
    });
  };

  document.querySelectorAll("[data-mode-choice]").forEach((button) => {
    button.addEventListener("click", () => {
      const mode = button.dataset.modeChoice;
      device.dataset.mode = mode;
      pressButtons("[data-mode-choice]", button);
      caption.textContent = mode === "capture"
        ? "A quiet nudge. You still choose when to shoot."
        : "A new JPEG preview. Your sample original stays untouched.";
      feedback.textContent = mode === "capture"
        ? "Sample controls only. FramedLocal never accesses your camera from this page."
        : "Preview the selected look, frame, and date stamp before saving a new copy.";
    });
  });

  document.querySelectorAll("[data-look-choice]").forEach((button) => {
    button.addEventListener("click", () => {
      device.dataset.look = button.dataset.lookChoice;
      pressButtons("[data-look-choice]", button);
      feedback.textContent = `${button.textContent.trim()} applied to the sample scene.`;
    });
  });

  document.querySelectorAll("[data-frame-choice]").forEach((button) => {
    button.addEventListener("click", () => {
      device.dataset.frame = button.dataset.frameChoice;
      pressButtons("[data-frame-choice]", button);
      feedback.textContent = `${button.textContent.trim()} selected for the print preview.`;
    });
  });

  guidanceToggle.addEventListener("click", () => {
    const enabled = device.dataset.guidance !== "on";
    device.dataset.guidance = enabled ? "on" : "off";
    guidanceToggle.classList.toggle("is-selected", enabled);
    guidanceToggle.setAttribute("aria-pressed", String(enabled));
    guidanceToggle.innerHTML = `<span aria-hidden="true">⌖</span> Guidance ${enabled ? "on" : "off"}`;
    feedback.textContent = enabled ? "Gentle composition guidance is visible in the sample." : "Guidance hidden. The camera preview stays clear.";
  });

  gridToggle.addEventListener("click", () => {
    const enabled = device.dataset.grid !== "on";
    device.dataset.grid = enabled ? "on" : "off";
    gridToggle.classList.toggle("is-selected", enabled);
    gridToggle.setAttribute("aria-pressed", String(enabled));
    gridToggle.innerHTML = `<span aria-hidden="true">▦</span> Grid ${enabled ? "on" : "off"}`;
    feedback.textContent = enabled ? "A light composition grid is visible in the sample." : "Grid hidden for an unobstructed view.";
  });

  dateToggle.addEventListener("change", () => {
    device.dataset.date = dateToggle.checked ? "on" : "off";
    feedback.textContent = dateToggle.checked ? "Date stamp added to the sample print." : "Date stamp removed from the sample print.";
  });

  document.querySelector("#switchLens").addEventListener("click", (event) => {
    const front = device.dataset.facing !== "front";
    device.dataset.facing = front ? "front" : "rear";
    lensLabel.textContent = front ? "FRONT CAMERA" : "REAR CAMERA";
    event.currentTarget.setAttribute("aria-pressed", String(front));
    feedback.textContent = front ? "Front-camera preview selected." : "Rear-camera preview selected.";
  });

  document.querySelector("#flipOrientation").addEventListener("click", (event) => {
    const landscape = device.dataset.orientation !== "landscape";
    device.dataset.orientation = landscape ? "landscape" : "portrait";
    event.currentTarget.setAttribute("aria-pressed", String(landscape));
    event.currentTarget.innerHTML = `<span aria-hidden="true">${landscape ? "▰" : "▱"}</span>`;
    feedback.textContent = landscape ? "Landscape sample orientation selected." : "Portrait sample orientation selected.";
  });

  shutter.addEventListener("click", () => {
    device.dataset.mode = "edit";
    pressButtons("[data-mode-choice]", document.querySelector('[data-mode-choice="edit"]'));
    caption.textContent = "Sample capture ready to shape. No camera was opened.";
    feedback.textContent = "Sample captured. Try a look or frame, then switch back to Camera.";
    shutter.classList.add("is-captured");
    window.setTimeout(() => shutter.classList.remove("is-captured"), 280);
  });

  document.querySelector("#resetDemo").addEventListener("click", () => {
    device.dataset.mode = "capture";
    device.dataset.look = "natural";
    device.dataset.frame = "white";
    device.dataset.orientation = "portrait";
    device.dataset.facing = "rear";
    device.dataset.guidance = "on";
    device.dataset.grid = "on";
    device.dataset.date = "on";
    updateZoomDial(1);
    dateToggle.checked = true;
    guidanceToggle.classList.add("is-selected");
    guidanceToggle.setAttribute("aria-pressed", "true");
    guidanceToggle.innerHTML = '<span aria-hidden="true">⌖</span> Guidance on';
    gridToggle.classList.add("is-selected");
    gridToggle.setAttribute("aria-pressed", "true");
    gridToggle.innerHTML = '<span aria-hidden="true">▦</span> Grid on';
    lensLabel.textContent = "REAR CAMERA";
    document.querySelector("#switchLens").setAttribute("aria-pressed", "false");
    document.querySelector("#flipOrientation").setAttribute("aria-pressed", "false");
    document.querySelector("#flipOrientation").innerHTML = '<span aria-hidden="true">▱</span>';
    pressButtons("[data-mode-choice]", document.querySelector('[data-mode-choice="capture"]'));
    pressButtons("[data-look-choice]", document.querySelector('[data-look-choice="natural"]'));
    pressButtons("[data-frame-choice]", document.querySelector('[data-frame-choice="white"]'));
    caption.textContent = "A quiet nudge. You still choose when to shoot.";
    feedback.textContent = "Preview reset. Pick a look, frame, or camera option to explore.";
  });
})();
