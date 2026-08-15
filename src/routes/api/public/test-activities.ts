import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/api/public/test-activities")({
  server: {
    handlers: {
      POST: async () => {
        console.log("🔥 test-activities POST HIT");

        return Response.json({
          ok: true,
          test: "test-activities",
        });
      },
    },
  },
});
