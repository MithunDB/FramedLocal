(() => {
  const device = document.querySelector("#demoDevice");
  const feedback = document.querySelector("#studioFeedback");
  const caption = document.querySelector("#deviceCaption");
  const lensLabel = document.querySelector("#lensLabel");
  const guidanceToggle = document.querySelector("#guidanceToggle");
  const gridToggle = document.querySelector("#gridToggle");
  const dateToggle = document.querySelector("#dateToggle");
  const shutter = document.querySelector("#shutter");
  const zoomDial = document.querySelector("#demoZoomDial");
  const zoomReadout = document.querySelector("#demoZoomValue");
  const zoomTicks = document.querySelector("#demoZoomTicks");
  const zoomPointer = document.querySelector("#demoZoomPointer");
  const zoomStops = document.querySelector("#demoZoomStops");
  let sampleZoom = 1;
  let zoomDragStart = null;
  let zoomHoldTimer = null;
  let zoomLongPressTriggered = false;
  const keyZoomStops = [0.5, 1, 2, 5];
  const zoomLogMin = Math.log2(0.5);
  const zoomLogMax = Math.log2(5);
  const zoomSnapTolerance = 0.08;
  const zoomProgress = (value) => (Math.log2(value) - zoomLogMin) / (zoomLogMax - zoomLogMin);

  const tickValues = [];
  const tickCount = Math.ceil((zoomLogMax - zoomLogMin) * 12);
  for (let index = 0; index <= tickCount; index += 1) {
    tickValues.push(2 ** (zoomLogMin + (zoomLogMax - zoomLogMin) * index / tickCount));
  }
  tickValues.push(...keyZoomStops);
  [...new Set(tickValues.map((value) => value.toFixed(6)))].map(Number).sort((a, b) => a - b).forEach((tickValue) => {
    const progress = zoomProgress(tickValue);
    const angle = Math.PI + Math.PI * progress;
    const isKeyStop = keyZoomStops.includes(tickValue);
    const inner = isKeyStop ? 111 : 118;
    const outer = 128;
    const tick = document.createElementNS("http://www.w3.org/2000/svg", "path");
    tick.setAttribute("d", `M ${140 + Math.cos(angle) * inner} ${155 + Math.sin(angle) * inner} L ${140 + Math.cos(angle) * outer} ${155 + Math.sin(angle) * outer}`);
    tick.classList.add("zoom-wheel-tick");
    if (isKeyStop) tick.classList.add("is-major");
    zoomTicks.append(tick);
  });

  for (const stop of keyZoomStops) {
    const angle = Math.PI + Math.PI * zoomProgress(stop);
    const label = document.createElementNS("http://www.w3.org/2000/svg", "text");
    label.setAttribute("x", String(140 + Math.cos(angle) * 91));
    label.setAttribute("y", String(155 + Math.sin(angle) * 91 + 3));
    label.classList.add("zoom-wheel-stop");
    label.textContent = `${stop}×`;
    zoomTicks.append(label);
  }

  const updateZoomDial = (requested) => {
    sampleZoom = Math.min(5, Math.max(0.5, requested));
    const snap = keyZoomStops
      .map((stop) => ({ stop, distance: Math.abs(Math.log2(sampleZoom / stop)) }))
      .filter(({ distance }) => distance <= zoomSnapTolerance)
      .sort((a, b) => a.distance - b.distance)[0];
    if (snap) sampleZoom = snap.stop;
    const progress = zoomProgress(sampleZoom);
    const angle = Math.PI + Math.PI * progress;
    const innerX = 140 + Math.cos(angle) * 105;
    const innerY = 155 + Math.sin(angle) * 105;
    const outerX = 140 + Math.cos(angle) * 126;
    const outerY = 155 + Math.sin(angle) * 126;
    zoomReadout.textContent = `${sampleZoom.toFixed(1)}×`;
    zoomDial.setAttribute("aria-valuenow", sampleZoom.toFixed(1));
    zoomDial.setAttribute("aria-valuetext", `${sampleZoom.toFixed(1)} times`);
    device.style.setProperty("--camera-zoom", String(Math.max(0.82, 1 + (sampleZoom - 1) * 0.36)));
    zoomPointer.setAttribute("d", `M ${innerX} ${innerY} L ${outerX} ${outerY}`);
    zoomStops.querySelectorAll("button").forEach((button) => {
      button.classList.toggle("is-selected", Math.abs(sampleZoom - Number(button.dataset.zoomStop)) < 0.04);
    });
  };

  const setZoomFromWheelPointer = (event) => {
    const bounds = zoomDial.getBoundingClientRect();
    if (event.clientX < bounds.left || event.clientX > bounds.right
        || event.clientY < bounds.top || event.clientY > bounds.bottom) return;
    const scaleX = bounds.width / 280;
    const scaleY = bounds.height / 155;
    const x = (event.clientX - (bounds.left + bounds.width / 2)) / scaleX;
    const y = (event.clientY - bounds.bottom) / scaleY;
    let angle = Math.atan2(y, x);
    if (angle < 0) angle += Math.PI * 2;
    angle = Math.min(Math.PI * 2, Math.max(Math.PI, angle));
    const progress = (angle - Math.PI) / Math.PI;
    updateZoomDial(2 ** (Math.log2(0.5) + progress * (Math.log2(5) - Math.log2(0.5))));
  };

  zoomDial.addEventListener("pointerdown", (event) => {
    zoomDragStart = true;
    zoomDial.setPointerCapture(event.pointerId);
    setZoomFromWheelPointer(event);
  });
  zoomDial.addEventListener("pointermove", (event) => {
    if (!zoomDragStart) return;
    setZoomFromWheelPointer(event);
  });
  const releaseWheel = () => {
    zoomDragStart = null;
    zoomDial.hidden = true;
  };
  zoomDial.addEventListener("pointerup", releaseWheel);
  zoomDial.addEventListener("pointercancel", releaseWheel);
  zoomDial.addEventListener("keydown", (event) => {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
    event.preventDefault();
    updateZoomDial(sampleZoom * 2 ** (event.key === "ArrowRight" ? 1 / 12 : -1 / 12));
  });
  zoomDial.addEventListener("keyup", (event) => {
    if (event.key === "ArrowLeft" || event.key === "ArrowRight" || event.key === "Escape") {
      zoomDial.hidden = true;
    }
  });
  zoomStops.querySelectorAll("button").forEach((button) => {
    const stop = Number(button.dataset.zoomStop);
    let holdOrigin = null;
    button.addEventListener("pointerdown", (event) => {
      zoomLongPressTriggered = false;
      holdOrigin = { x: event.clientX, y: event.clientY };
      button.setPointerCapture(event.pointerId);
      zoomHoldTimer = window.setTimeout(() => {
        zoomLongPressTriggered = true;
        updateZoomDial(stop);
        zoomDial.hidden = false;
      }, 150);
    });
    button.addEventListener("pointermove", (event) => {
      if (!zoomLongPressTriggered || !holdOrigin) return;
      if (Math.hypot(event.clientX - holdOrigin.x, event.clientY - holdOrigin.y) > 10) {
        setZoomFromWheelPointer(event);
      }
    });
    const releaseStop = () => {
      window.clearTimeout(zoomHoldTimer);
      if (zoomLongPressTriggered) zoomDial.hidden = true;
      holdOrigin = null;
    };
    button.addEventListener("pointerup", releaseStop);
    button.addEventListener("pointercancel", releaseStop);
    button.addEventListener("click", () => {
      if (zoomLongPressTriggered) {
        zoomLongPressTriggered = false;
        return;
      }
      updateZoomDial(stop);
    });
  });
  updateZoomDial(sampleZoom);
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
    zoomDial.hidden = true;
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
