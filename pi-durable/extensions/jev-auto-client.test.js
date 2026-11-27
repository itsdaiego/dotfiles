import assert from "node:assert/strict";
import test from "node:test";

import setupJevRouteStatus from "./jev-auto-client.js";

const flush = async () => {
    await Promise.resolve();
    await Promise.resolve();
};

test("shows and remembers the current Jev route for the open conversation", async (context) => {
    const stored = new Map();
    const originalStorage = Object.getOwnPropertyDescriptor(globalThis, "localStorage");
    Object.defineProperty(globalThis, "localStorage", {
        configurable: true,
        value: {
            getItem(key) {
                return stored.get(key) ?? null;
            },
            setItem(key, value) {
                stored.set(key, String(value));
            },
            removeItem(key) {
                stored.delete(key);
            },
        },
    });
    context.after(() => {
        if (originalStorage) {
            Object.defineProperty(globalThis, "localStorage", originalStorage);
        } else {
            delete globalThis.localStorage;
        }
    });

    let conversationListener;
    let routeListener;
    let status;
    const creations = [];
    const updates = [];
    let removed = 0;
    const routes = new Map([
        [42, "Claude Sonnet 5.5"],
        [84, null],
    ]);
    const pocket = {
        api: async (path) => {
            const conversationId = Number(path.split("/").at(-1));

            return { label: routes.get(conversationId) ?? null };
        },
        on(event, listener) {
            assert.equal(event, "route");
            routeListener = listener;

            return () => {};
        },
        onConversation(listener) {
            conversationListener = listener;

            return () => {};
        },
        status(spec) {
            status = spec;
            creations.push(spec);

            return {
                update(patch) {
                    updates.push(patch);
                },
                remove() {
                    removed++;
                },
            };
        },
    };

    setupJevRouteStatus(pocket);
    conversationListener(42);
    await flush();

    assert.equal(status.text, "Jev → Claude Sonnet 5.5");
    assert.equal(status.short, "Jev → Sonnet 5.5");

    routeListener({ conversationId: 42, label: "GPT-6 Sol" });
    assert.equal(stored.get("x.jev-auto.route.42"), "GPT-6 Sol");
    assert.deepEqual(updates.at(-1), {
        text: "Jev → GPT-6 Sol",
        short: "Jev → GPT-6 Sol",
        title: "Jev Auto routed the current task to GPT-6 Sol.",
    });

    routeListener({ conversationId: 7, label: "Claude Opus 5.5" });
    assert.equal(updates.length, 1);

    conversationListener(84);
    await flush();
    assert.equal(removed, 1);

    stored.set("x.jev-auto.route.84", "Claude Opus 5.5");
    conversationListener(84);
    await flush();

    assert.equal(creations.at(-1).text, "Jev → Claude Opus 5.5");
    assert.equal(removed, 1);
});
