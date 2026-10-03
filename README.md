<div align="center">

<img src="assets/agent_rio_banner.webp" alt="Agent Rio - Always-on AI Agents" width="100%" style="border-radius: 12px; margin-bottom: 20px;" />

# Agent Rio
### Autonomous Voice-Activated Android AI Companion & Automation Agent

[![Build APK](https://github.com/Manik51/Agent-Rio/actions/workflows/build-apk.yml/badge.svg)](https://github.com/Manik51/Agent-Rio/actions/workflows/build-apk.yml)
[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Android-8.0+-3DDC84?logo=android&logoColor=white)](https://developer.android.com)
[![Rive](https://img.shields.io/badge/Rive-Interactive%20Avatar-FF5252?logo=rive&logoColor=white)](https://rive.app)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

<p align="center">
  <a href="#-what-agent-rio-can-do"><b>Capabilities</b></a> •
  <a href="#-interactive-rive-avatar"><b>Official Avatar</b></a> •
  <a href="#-supported-ai-providers--api-keys"><b>Supported AI Keys</b></a> •
  <a href="#-download--installation"><b>Download APK</b></a>
</p>

</div>

---

## ⚡ What Agent Rio Can Do

Agent Rio transforms your Android phone into an autonomous AI workstation. Instead of just answering text prompts, Rio sees your screen, understands UI layouts, speaks naturally, and executes real multi-step tasks across all your installed apps.

### 📱 1. Autonomous Screen & App Automation
* **Visual UI Navigation:** Parses Android accessibility nodes to locate buttons, text inputs, search bars, icons, and menus on any screen.
* **Auto-Taps & Gestures:** Taps coordinates, types text into form fields, presses enter, scrolls through feeds, and swipes through menus.
* **Complex Multi-Step Goals:** Say *"Open YouTube and search for Lo-Fi music"* or *"Open Settings and check my battery status"*—Rio plans and executes each tap automatically.
* **Universal App Launcher:** Launch any application or system setting instantly by voice (*"Open WhatsApp"*, *"Launch Camera"*).

### 🎙️ 2. Dual-Trigger System (Hands-Free or Tap-to-Talk)
* **Hands-Free Wake Word:** Just say **"Hey Rio"** or **"Rio"** from anywhere to activate listening without touching your device.
* **Interactive Tap-to-Talk:** Tap the persistent floating companion avatar at any time to instantly start speaking.

### ⚡ 3. Fast-Path Offline Hardware Macros (Zero Latency)
Rio executes critical hardware controls instantly **even without an active internet connection**:
* **Bedtime Routine:** *"Turn off WiFi and Bluetooth, good night"* (turns off radios, lowers volume, and locks the screen in one command).
* **Radios & Connectivity:** Instant toggles for Wi-Fi and Bluetooth.
* **Audio Controls:** Rapid media volume changes, muting, and unmuting.
* **Device Control:** Back button simulation, notifications shade pull-down, quick settings opening, and screen locking.

### 📞 4. WhatsApp AI Voice Calling & Auto-Messaging
* **Voice Note Synthesis:** Converts spoken instructions into high-fidelity voice notes using neural voice synthesis.
* **Autonomous WhatsApp Dispatch:** Opens WhatsApp, searches for the recipient, attaches the generated audio note, and taps Send automatically.
* **Screen Observation Loop:** Monitors the chat screen for incoming contact replies and reads them aloud to you.

### 🗣️ 5. Hybrid Neural Speech Engine (TTS)
* **Alexa-Grade Neural Speech:** High-fidelity natural human voice for all spoken replies when online.
* **Seamless Offline Fallback:** Automatically drops back to on-device Android TTS when connectivity drops, ensuring Rio never goes mute.

### 🧸 6. Persistent System-Wide Floating Companion
* **Always Accessible:** Floats above all other applications, games, and home screens.
* **Physics & Snap-to-Edge:** Draggable anywhere on the screen with automatic edge docking and smooth animations.

---

## 🤖 Interactive Rive Avatar

Agent Rio features an official, stateful vector animation avatar powered by **Rive** ([`assets/Rio.riv`](assets/Rio.riv)).

The avatar dynamically reflects Rio's real-time cognitive and operational state:

| State | Avatar Behavior | Trigger / Input |
| :--- | :--- | :--- |
| **💤 Idle** | Relaxed breathing and ambient eye motion | Default state (`Idle9`) |
| **🎙️ Listening** | Active attentive posture ready for voice input | `typingBoolean = true` |
| **⚙️ Working** | Dynamic loading loop while reasoning or executing taps | `loadingBoolean = true` |
| **✨ Success** | Celebratory expression when a task is completed | `correct` trigger (`Correct9`) |
| **⚠️ Error** | Alert expression if a command fails or network is lost | `wrong` trigger (`Wrong9`) |
| **👆 Interactive** | Playful jump and reaction on tap or double-tap | `jump` trigger (`Jump9`) |

*Users can also switch between other cute companion styles in **Settings** (Pinky Chill, Professor Pip, Blue Beret, Froggy, Hearty, or GPT Dots).*

---

## 🔑 Supported AI Providers & API Keys

Agent Rio is completely provider-agnostic. You can power Rio's brain using any of the following API keys directly from **Settings**:

### 1. 🌟 Google Gemini API *(Recommended for Speed & Free Tier)*
* **Supported Models:** `gemini-2.0-flash`, `gemini-1.5-flash`, `gemini-1.5-pro`
* **Where to get a key:** [Google AI Studio](https://aistudio.google.com) *(Generous free quota available)*
* **Best for:** Fastest response times, low latency, and superior screen context comprehension.

### 2. 🚀 OpenRouter API *(Access Frontier Models)*
* **Supported Models:** Claude 3.5 Sonnet, Llama 3.3 70B, DeepSeek R1, GPT-4o, Mistral Large
* **Where to get a key:** [OpenRouter Keys](https://openrouter.ai/keys)
* **Best for:** Accessing any leading frontier AI model with a single unified API key.

### 3. 🧠 DeepSeek API
* **Supported Models:** `deepseek-chat` (DeepSeek-V3), `deepseek-reasoner` (DeepSeek-R1)
* **Where to get a key:** [DeepSeek Platform](https://platform.deepseek.com)
* **Best for:** Cost-effective deep reasoning and complex logic tasks.

### 4. ⚡ NVIDIA NIM API *(Free Developer Tier)*
* **Supported Models:** `z-ai/glm-5.2`, `meta/llama-3.3-70b-instruct`, `mistralai/mistral-nemotron`
* **Where to get a key:** [NVIDIA NGC Catalog](https://build.nvidia.com)
* **Best for:** Free verified chat endpoints with high throughput.

### 5. 🎙️ Amazon Polly (Optional for Voice Engine)
* **Parameters:** AWS Access Key ID & AWS Secret Access Key
* **Best for:** Authentic Alexa Joanna / Matthew neural voice synthesis.

---

## 📲 Download & Installation

### Step 1: Download the Signed Release APK
1. Open the [**GitHub Actions Tab**](https://github.com/Manik51/Agent-Rio/actions) or [**Releases**](https://github.com/Manik51/Agent-Rio/releases).
2. Click the latest green workflow run.
3. Download the **`AgentRio-APKs`** ZIP archive from **Artifacts**.
4. Extract the ZIP to obtain **`AgentRio-Universal-Release.apk`**.

### Step 2: Android Play Protect Bypass
Because Agent Rio is distributed directly via GitHub rather than the Google Play Store, Android Play Protect may show a verification dialog upon installation:

> **How to install smoothly:**  
> When the prompt appears:  
> 1. Tap **More details** *(or "বিস্তারিত দেখুন")*.  
> 2. Tap **Install anyway** *(or "যেকোনো উপায়ে ইনস্টল করুন")*.  
> 3. The app is securely signed with Agent Rio's official release key and will install immediately.

### Step 3: Enable Permissions
1. **Display Over Other Apps:** Allows Rio's Rive companion to float over other apps.
2. **Accessibility Service:** Enable **Agent Rio Screen Control** in Android Settings so Rio can read screen text and automate taps.
3. **Microphone & Battery:** Grant microphone permission for voice commands and disable battery optimization so Rio remains responsive in the background.

---

## 📄 License

Agent Rio is released under the **MIT License**.  
Maintained and developed by [Manik Shil](https://github.com/Manik51).
