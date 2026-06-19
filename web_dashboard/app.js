// DOM Elements
const connectBtn = document.getElementById('connect-btn');
const connectionStatus = document.getElementById('connection-status');
const connectionDot = document.getElementById('connection-dot');
const imuLog = document.getElementById('imu-log');

// Processed Data UI Elements
const stepsVal = document.getElementById('steps-val');
const pushupsVal = document.getElementById('pushups-val');
const pitchVal = document.getElementById('pitch-val');
const rollVal = document.getElementById('roll-val');
const leanDir = document.getElementById('lean-dir');
const tiltDir = document.getElementById('tilt-dir');
const postureStatusBadge = document.getElementById('posture-status-badge');

// Counters
const logCounters = {
    'imu-log': 0
};
const counterElems = {
    'imu-log': document.getElementById('imu-counter')
};

// BLE UUIDs (Matching config.h)
const SPORT_SERVICE_UUID    = "6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c10";
const CHAR_SENSOR_DATA_UUID = "6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c11"; // Processed sensor data
const CHAR_RAW_UUID         = "6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c14"; // Raw sensor data

// State
let bluetoothDevice = null;
let server = null;

// Utility: Get current timestamp
function getTimestamp() {
    const now = new Date();
    const ms = now.getMilliseconds().toString().padStart(3, '0');
    return `[${now.toLocaleTimeString('en-US', { hour12: false })}.${ms}]`;
}

// Utility: Append log to a specific terminal
function appendLog(terminalElem, message, type = 'data') {
    const entry = document.createElement('div');
    entry.className = `log-entry ${type}`;
    
    const timestampSpan = document.createElement('span');
    timestampSpan.className = 'timestamp';
    timestampSpan.textContent = getTimestamp();
    
    const messageSpan = document.createElement('span');
    if (message.includes("WARNING") || message.includes("ERROR")) {
        messageSpan.className = 'highlight';
    }
    messageSpan.textContent = ` ${message}`;

    entry.appendChild(timestampSpan);
    entry.appendChild(messageSpan);

    terminalElem.appendChild(entry);
    
    // Auto-scroll
    terminalElem.scrollTop = terminalElem.scrollHeight;

    // Increment Counter
    if (logCounters[terminalElem.id] !== undefined) {
        logCounters[terminalElem.id]++;
        counterElems[terminalElem.id].textContent = logCounters[terminalElem.id];
    }

    // Keep log size manageable (max 100 lines per terminal)
    if (terminalElem.children.length > 100) {
        terminalElem.removeChild(terminalElem.firstChild);
    }
}

// Parse Raw Sensor Data Struct (20 bytes: accel + gyro + mag + hrRaw)
function handleRawData(event) {
    const view = event.target.value;
    
    if (view.byteLength === 20) {
        const ax = view.getInt16(0, true);
        const ay = view.getInt16(2, true);
        const az = view.getInt16(4, true);
        const gx = view.getInt16(6, true);
        const gy = view.getInt16(8, true);
        const gz = view.getInt16(10, true);
        const mx = view.getInt16(12, true);
        const my = view.getInt16(14, true);
        const mz = view.getInt16(16, true);
        const hrRaw = view.getUint16(18, true);

        appendLog(imuLog, `AX:${ax} AY:${ay} AZ:${az} | GX:${gx} GY:${gy} GZ:${gz} | MX:${mx} MY:${my} MZ:${mz}`, 'data');
    }
}

// Parse Processed Sensor Data Struct (18 bytes: hr + steps + pushups + pitch + roll)
function handleSensorData(event) {
    const view = event.target.value;
    
    if (view.byteLength === 18) {
        const hr = view.getUint16(0, true);
        const steps = view.getUint32(2, true);
        const pushups = view.getUint32(6, true);
        const pitch = view.getFloat32(10, true).toFixed(1);
        const roll = view.getFloat32(14, true).toFixed(1);

        // Update UI Processed Grid
        updateValueWithAnimation(stepsVal, steps);
        updateValueWithAnimation(pushupsVal, pushups);
        updateValueWithAnimation(pitchVal, pitch);
        updateValueWithAnimation(rollVal, roll);

        // Posture Warning Logic (>10 degrees is considered bad posture)
        const postureCard = pitchVal.closest('.glass-card');
        const isBadPitch = Math.abs(pitch) > 10;
        const isBadRoll = Math.abs(roll) > 10;

        // Update direction texts
        if (leanDir) {
            if (pitch > 5) { leanDir.textContent = "Forward"; leanDir.style.color = isBadPitch ? "var(--accent-danger)" : "var(--text-main)"; }
            else if (pitch < -5) { leanDir.textContent = "Backward"; leanDir.style.color = isBadPitch ? "var(--accent-danger)" : "var(--text-main)"; }
            else { leanDir.textContent = "Centered"; leanDir.style.color = "var(--text-muted)"; }
        }

        if (tiltDir) {
            if (roll > 5) { tiltDir.textContent = "Right"; tiltDir.style.color = isBadRoll ? "var(--accent-danger)" : "var(--text-main)"; }
            else if (roll < -5) { tiltDir.textContent = "Left"; tiltDir.style.color = isBadRoll ? "var(--accent-danger)" : "var(--text-main)"; }
            else { tiltDir.textContent = "Centered"; tiltDir.style.color = "var(--text-muted)"; }
        }

        if (isBadPitch || isBadRoll) {
            postureCard.classList.add('warning-glow');
            if (isBadPitch) pitchVal.classList.add('warning-text');
            else pitchVal.classList.remove('warning-text');
            
            if (isBadRoll) rollVal.classList.add('warning-text');
            else rollVal.classList.remove('warning-text');

            if (postureStatusBadge) {
                postureStatusBadge.textContent = "BAD POSTURE";
                postureStatusBadge.style.background = "rgba(239, 68, 68, 0.15)";
                postureStatusBadge.style.color = "#ef4444";
                postureStatusBadge.style.borderColor = "rgba(239, 68, 68, 0.3)";
            }
        } else {
            postureCard.classList.remove('warning-glow');
            pitchVal.classList.remove('warning-text');
            rollVal.classList.remove('warning-text');

            if (postureStatusBadge) {
                postureStatusBadge.textContent = "GOOD";
                postureStatusBadge.style.background = "rgba(16, 185, 129, 0.15)";
                postureStatusBadge.style.color = "#10b981";
                postureStatusBadge.style.borderColor = "rgba(16, 185, 129, 0.3)";
            }
        }
    }
}

function updateValueWithAnimation(element, newValue) {
    if (element && element.textContent !== newValue.toString()) {
        element.style.transform = 'scale(1.1)';
        element.textContent = newValue;
        setTimeout(() => {
            element.style.transform = 'scale(1)';
        }, 150);
    }
}

// Helper: Try subscribing to a BLE characteristic
async function trySubscribe(service, uuid, handler, label) {
    try {
        const char = await service.getCharacteristic(uuid);
        await char.startNotifications();
        char.addEventListener('characteristicvaluechanged', handler);
        console.log(`Subscribed to ${label}`);
        return true;
    } catch (e) {
        console.warn(`${label} not available: ${e.message}`);
        return false;
    }
}

// Disconnect handler
function onDisconnected(event) {
    console.log("Device disconnected.");
    appendLog(imuLog, 'BLE Disconnected.', 'warn');
    
    // Reset Processed UI
    const postureCard = pitchVal ? pitchVal.closest('.glass-card') : null;
    if (postureCard) postureCard.classList.remove('warning-glow');
    if (pitchVal) pitchVal.classList.remove('warning-text');
    if (rollVal) rollVal.classList.remove('warning-text');
    if (leanDir) { leanDir.textContent = "Centered"; leanDir.style.color = "var(--text-muted)"; }
    if (tiltDir) { tiltDir.textContent = "Centered"; tiltDir.style.color = "var(--text-muted)"; }
    if (postureStatusBadge) {
        postureStatusBadge.textContent = "GOOD";
        postureStatusBadge.style.background = "rgba(16, 185, 129, 0.15)";
        postureStatusBadge.style.color = "#10b981";
        postureStatusBadge.style.borderColor = "rgba(16, 185, 129, 0.3)";
    }
    
    resetUI();
}

// Reset UI state
function resetUI() {
    bluetoothDevice = null;
    server = null;
    connectionStatus.textContent = 'Disconnected';
    connectionDot.className = 'dot disconnected';
    connectBtn.innerHTML = `CONNECT DEVICE`;
}

// Web Bluetooth Connection Logic
connectBtn.addEventListener('click', async () => {
    if (bluetoothDevice && bluetoothDevice.gatt.connected) {
        bluetoothDevice.gatt.disconnect();
        return;
    }

    try {
        if (!navigator.bluetooth) {
            const errMsg = "Web Bluetooth API not supported. Use Chrome/Edge on localhost or HTTPS.";
            console.error(errMsg);
            appendLog(imuLog, `ERROR: ${errMsg}`, 'error');
            return;
        }

        console.log("Requesting Bluetooth Device...");
        
        bluetoothDevice = await navigator.bluetooth.requestDevice({
            filters: [{ namePrefix: "SportTracker" }],
            optionalServices: [SPORT_SERVICE_UUID]
        });

        bluetoothDevice.addEventListener('gattserverdisconnected', onDisconnected);

        console.log(`Connecting to GATT Server on ${bluetoothDevice.name}...`);
        connectBtn.innerHTML = `CONNECTING...`;
        
        server = await bluetoothDevice.gatt.connect();
        
        console.log("Connected to GATT Server. Getting Services...");
        const service = await server.getPrimaryService(SPORT_SERVICE_UUID);

        // Subscribe to Raw Data
        const hasRaw = await trySubscribe(service, CHAR_RAW_UUID, handleRawData, "Raw Sensor Data");
        if (hasRaw) {
            appendLog(imuLog, 'Streaming raw IMU data...', 'system');
        } else {
            appendLog(imuLog, 'WARNING: Raw characteristic not found!', 'warn');
        }

        // Subscribe to Processed Activity Data
        const hasSensor = await trySubscribe(service, CHAR_SENSOR_DATA_UUID, handleSensorData, "Activity Data");
        if (hasSensor) {
            console.log('Streaming activity tracking data...');
        } else {
            console.log('WARNING: Activity characteristic not found!');
        }

        // Update UI
        connectionStatus.textContent = 'Connected (BLE)';
        connectionDot.className = 'dot connected';
        connectBtn.innerHTML = `DISCONNECT`;
        console.log("Telemetry stream established successfully.");

    } catch (error) {
        console.error(`ERROR: ${error.message}`);
        appendLog(imuLog, `ERROR: ${error.message}`, 'error');
        resetUI();
    }
});
