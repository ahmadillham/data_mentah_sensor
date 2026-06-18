// DOM Elements
const connectBtn = document.getElementById('connect-btn');
const connectionStatus = document.getElementById('connection-status');
const connectionDot = document.getElementById('connection-dot');
const imuLog = document.getElementById('imu-log');
const hrLog = document.getElementById('hr-log');
const activityLog = document.getElementById('activity-log');

// Counters
const logCounters = {
    'imu-log': 0,
    'hr-log': 0,
    'activity-log': 0
};
const counterElems = {
    'imu-log': document.getElementById('imu-counter'),
    'hr-log': document.getElementById('hr-counter'),
    'activity-log': document.getElementById('activity-counter')
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

        appendLog(hrLog, `ADC_RAW:${hrRaw}`, 'data');
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

        appendLog(hrLog, `BPM:${hr}`, 'data');
        appendLog(activityLog, `STEPS:${steps} PUSHUPS:${pushups} PITCH:${pitch}° ROLL:${roll}°`, 'data');
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
    appendLog(hrLog, 'BLE Disconnected.', 'warn');
    appendLog(activityLog, 'BLE Disconnected.', 'warn');
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
            appendLog(hrLog, 'Streaming raw ADC data...', 'system');
        } else {
            appendLog(imuLog, 'WARNING: Raw characteristic not found!', 'warn');
        }

        // Subscribe to Processed Activity Data
        const hasSensor = await trySubscribe(service, CHAR_SENSOR_DATA_UUID, handleSensorData, "Activity Data");
        if (hasSensor) {
            appendLog(activityLog, 'Streaming activity tracking data...', 'system');
        } else {
            appendLog(activityLog, 'WARNING: Activity characteristic not found!', 'warn');
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
