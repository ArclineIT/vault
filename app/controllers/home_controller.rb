# The unauthenticated front door: says what this is and nothing else.
class HomeController < ApplicationController
  def show
    render json: { service: "arcline-vault", api: "/v1", docs: "https://git.ridgwaysystems.org/ArclineIT/vault" }
  end
end
