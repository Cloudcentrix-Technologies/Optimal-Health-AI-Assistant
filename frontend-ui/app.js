const CONFIG = {
    region: "us-east-1",
    clientId: "6nnhnaqq8nhcclkrtm3l0imhvu",
    apiUrl: "https://bcc9u7o40b.execute-api.us-east-1.amazonaws.com/chat"
};

let idToken = null;

const loginScreen = document.getElementById("login-screen");
const appScreen = document.getElementById("app-screen");

const loginForm = document.getElementById("login-form");
const loginError = document.getElementById("login-error");
const loginButton = document.getElementById("login-button");

const chatForm = document.getElementById("chat-form");
const questionInput = document.getElementById("question");
const chatContainer = document.getElementById("chat-container");

const loading = document.getElementById("loading");
const sendButton = document.getElementById("send-button");

const signOutButton = document.getElementById("sign-out-button");

function showApp() {
    loginScreen.classList.add("hidden");
    appScreen.classList.remove("hidden");
    questionInput.focus();
}

function showLogin() {
    appScreen.classList.add("hidden");
    loginScreen.classList.remove("hidden");
    loginForm.reset();
}

function addMessage(text, type, sources = []) {
    const message = document.createElement("div");
    message.className = `message ${type}`;

    const textElement = document.createElement("div");
    textElement.textContent = text;
    message.appendChild(textElement);

    if (sources && sources.length > 0) {
        const source = document.createElement("div");
        source.className = "source";
        source.textContent = `Source: ${sources.join(", ")}`;
        message.appendChild(source);
    }

    chatContainer.appendChild(message);

    window.scrollTo({
        top: document.body.scrollHeight,
        behavior: "smooth"
    });
}

function setLoading(state) {
    loading.classList.toggle("hidden", !state);
    sendButton.disabled = state;
    questionInput.disabled = state;
}

async function login(email, password) {
    const endpoint = `https://cognito-idp.${CONFIG.region}.amazonaws.com/`;

    const response = await fetch(endpoint, {
        method: "POST",
        headers: {
            "Content-Type": "application/x-amz-json-1.1",
            "X-Amz-Target": "AWSCognitoIdentityProviderService.InitiateAuth"
        },
        body: JSON.stringify({
            AuthFlow: "USER_PASSWORD_AUTH",
            ClientId: CONFIG.clientId,
            AuthParameters: {
                USERNAME: email,
                PASSWORD: password
            }
        })
    });

    const data = await response.json();

    if (!response.ok || !data.AuthenticationResult) {
        throw new Error(
            data.message || "Unable to sign in. Check your credentials."
        );
    }

    idToken = data.AuthenticationResult.IdToken;
}

loginForm.addEventListener("submit", async (event) => {
    event.preventDefault();

    loginError.textContent = "";
    loginButton.disabled = true;
    loginButton.textContent = "Signing in...";

    const email = document.getElementById("email").value.trim();
    const password = document.getElementById("password").value;

    try {
        await login(email, password);
        showApp();
    } catch (error) {
        loginError.textContent = error.message;
    } finally {
        loginButton.disabled = false;
        loginButton.textContent = "Sign in";
    }
});

chatForm.addEventListener("submit", async (event) => {
    event.preventDefault();

    const question = questionInput.value.trim();

    if (!question || !idToken) {
        return;
    }

    addMessage(question, "user-message");

    questionInput.value = "";
    setLoading(true);

    try {
        const response = await fetch(CONFIG.apiUrl, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${idToken}`
            },
            body: JSON.stringify({
                question: question
            })
        });

        const data = await response.json();

        if (!response.ok) {
            throw new Error(
                data.message || "The assistant could not process your question."
            );
        }

        addMessage(
            data.answer || "No answer was returned.",
            "ai-message",
            data.sources || []
        );

    } catch (error) {
        addMessage(
            `Unable to get a response: ${error.message}`,
            "ai-message"
        );
    } finally {
        setLoading(false);
        questionInput.focus();
    }
});

signOutButton.addEventListener("click", () => {
    idToken = null;
    chatContainer.innerHTML = "";
    showLogin();
});