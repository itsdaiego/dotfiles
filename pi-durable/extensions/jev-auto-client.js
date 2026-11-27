/** Shows the physical model Jev Auto chose for the current task. */
export const pocketApi = 1;

const shortLabel = (label) => label.replace(/^Claude /, "");
const routeKey = (conversationId) => `x.jev-auto.route.${conversationId}`;

const recall = (conversationId) => {
    try {
        return globalThis.localStorage?.getItem(routeKey(conversationId)) ?? null;
    } catch {
        return null;
    }
};

const remember = (conversationId, label) => {
    try {
        if (label) {
            globalThis.localStorage?.setItem(routeKey(conversationId), label);
        }
    } catch {}
};

export default function setupJevRouteStatus(pocket) {
    let shown = null;
    let status = null;
    let request = 0;

    const publish = (label) => {
        if (!label || typeof pocket.status !== "function") {
            status?.remove();
            status = null;

            return;
        }

        const item = {
            id: "route",
            text: `Jev → ${label}`,
            short: `Jev → ${shortLabel(label)}`,
            title: `Jev Auto routed the current task to ${label}.`,
            after: "core:cache",
        };

        if (status === null) {
            status = pocket.status(item);
        } else {
            status.update({ text: item.text, short: item.short, title: item.title });
        }
    };

    const load = (conversationId) => {
        shown = conversationId;
        const current = ++request;

        if (conversationId === null) {
            publish(null);
            return;
        }

        const cached = recall(conversationId);
        publish(cached);
        pocket.api(`route/${conversationId}`).then(
            ({ label }) => {
                if (request === current && shown === conversationId && label) {
                    remember(conversationId, label);
                    publish(label);
                }
            },
            () => {},
        );
    };

    pocket.on("route", ({ conversationId, label }) => {
        remember(conversationId, label);
        if (conversationId === shown) {
            publish(label);
        }
    });

    if (typeof pocket.onConversation === "function") {
        pocket.onConversation(load);
    } else {
        load(pocket.conversationId());
    }

    return () => status?.remove();
}
