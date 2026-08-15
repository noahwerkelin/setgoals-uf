import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/api/public/nearby-activities")({
  server: {
    handlers: {
      POST: async () => {
        console.log("🔥 nearby-activities POST HIT");
        return Response.json({
          ok: true,
          test: "nearby-activities",
        });
      },
    },
  },
});
